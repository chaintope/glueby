module Glueby
  module Contract
    module AR
      class Timestamp < ::ActiveRecord::Base
        include Glueby::GluebyLogger

        enum status: { init: 0, unconfirmed: 1, confirmed: 2 }
        enum timestamp_type: { simple: 0, trackable: 1 }

        attr_reader :tx

        belongs_to :prev, class_name: 'Glueby::Contract::AR::Timestamp', optional: true

        validate :validate_prev

        class << self
          def digest_content(content, digest)
            case digest&.downcase
            when :sha256
              Tapyrus.sha256(content).bth
            when :double_sha256
              Tapyrus.double_sha256(content).bth
            when :none
              content
            else
              raise Glueby::Contract::Errors::UnsupportedDigestType
            end
          end
        end

        # @param [Hash] attributes attributes which consist of:
        # - wallet_id
        # - content
        # - prefix(optional)
        # - timestamp_type(optional)
        # @raise [Glueby::ArgumentError] If the timestamp_type is not in :simple or :trackable
        def initialize(attributes = nil)
          # Set content_hash from :content attribute
          content_hash = Timestamp.digest_content(attributes[:content], attributes[:digest] || :sha256)
          super(
            wallet_id: attributes[:wallet_id],
            content_hash: content_hash,
            prefix: attributes[:prefix] ? attributes[:prefix] : '',
            status: :init,
            timestamp_type: attributes[:timestamp_type] || :simple,
            prev_id: attributes[:prev_id]
          )
        rescue ::ArgumentError => e
          raise Glueby::ArgumentError, e.message
        end

        # Return true if timestamp type is 'trackable' and output in timestamp transaction has not been spent yet, otherwise return false.
        def latest?
          trackable? && attributes['latest']
        end
        alias_method :latest, :latest?

        # Returns a UTXO that corresponds to the timestamp
        # @return [Hash] UTXO
        #   - [String] script_pubkey A script pubkey hex string
        #   - [String] txid A txid
        #   - [Integer] vout An index of the tx
        #   - [Integer] amount A value of
        def utxo
          {
            script_pubkey: Tapyrus::Script.parse_from_addr(p2c_address).to_hex,
            txid: txid,
            vout: Contract::Timestamp::TxBuilder::PAY_TO_CONTRACT_INPUT_INDEX,
            amount: Glueby::Contract::Timestamp::P2C_DEFAULT_VALUE
          }
        end

        # Broadcast and save timestamp
        # @param [Glueby::Contract::FixedFeeEstimator] fee_estimator
        # @param [Glueby::UtxoProvider] utxo_provider
        # @return true if tapyrus transactions were broadcasted and the timestamp was updated successfully, otherwise false.
        def save_with_broadcast(fee_estimator: Glueby::Contract::FixedFeeEstimator.new, utxo_provider: nil)
          save_with_broadcast!(fee_estimator: fee_estimator, utxo_provider: utxo_provider)
        rescue Errors::FailedToBroadcast,
               Errors::PrevTimestampNotFound,
               Errors::PrevTimestampIsNotTrackable,
               Errors::PrevTimestampAlreadyUpdated => e
          logger.error("failed to broadcast (id=#{id}, reason=#{e.message})")
          false
        end

        # Broadcast and save timestamp, and it raises errors
        # @param [Glueby::Contract::FixedFeeEstimator] fee_estimator
        # @param [Glueby::UtxoProvider] utxo_provider
        # @return true if tapyrus transactions were broadcasted and the timestamp was updated successfully
        # @raise [Glueby::Contract::Errors::FailedToBroadcast] If the broadcasting is failure
        # @raise [Glueby::Contract::Errors::PrevTimestampNotFound] If it is not available that the timestamp record which correspond with the prev_id attribute
        # @raise [Glueby::Contract::Errors::PrevTimestampIsNotTrackable] If the timestamp record by prev_id is not trackable
        # @raise [Glueby::Contract::Errors::PrevTimestampAlreadyUpdated] If the previous timestamp was already updated
        def save_with_broadcast!(fee_estimator: Glueby::Contract::FixedFeeEstimator.new, utxo_provider: nil)
          validate_prev!
          utxo_provider = Glueby::UtxoProvider.new if !utxo_provider && Glueby.configuration.use_utxo_provider?

          funding_tx, tx, p2c_address, payment_base = create_txs(fee_estimator, utxo_provider)

          if funding_tx
            ::ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
              wallet.internal_wallet.broadcast(funding_tx)
            end
            logger.info("funding tx was broadcasted(id=#{id}, funding_tx.txid=#{funding_tx.txid})")
          end
          ::ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
            wallet.internal_wallet.broadcast(tx) do |tx|
              assign_attributes(txid: tx.txid, status: :unconfirmed, p2c_address: p2c_address, payment_base: payment_base)
              @tx = tx
              save!(validate: false) # The validation is already executed at head of #save_with_broadcast!

              if update_trackable?
                prev.latest = false
                prev.save!
              end
            end
          end
          logger.info("timestamp tx was broadcasted (id=#{id}, txid=#{tx.txid})")
          true
        rescue ActiveRecord::RecordInvalid,
               Tapyrus::RPC::Error,
               Internal::Wallet::Errors::WalletAlreadyLoaded,
               Internal::Wallet::Errors::WalletNotFound,
               Errors::InsufficientFunds => e
          errors.add(:base, "failed to broadcast (id=#{id}, reason=#{e.message})")
          raise Errors::FailedToBroadcast, "failed to broadcast (id=#{id}, reason=#{e.message})"
        end

        private

        def wallet
          @wallet ||= Glueby::Wallet.load(wallet_id)
        end

        def create_txs(fee_estimator, utxo_provider)
          builder = builder_class.new(wallet, fee_estimator)

          if builder.instance_of?(Contract::Timestamp::TxBuilder::UpdatingTrackable)
            builder.set_prev_timestamp_info(
              timestamp_utxo: prev.utxo,
              payment_base: prev.payment_base,
              prefix: prev.prefix,
              data: prev.content_hash
            )
          end

          tx = builder.set_data(prefix, content_hash)
                      .set_inputs(utxo_provider)
                      .build

          if builder.instance_of?(Contract::Timestamp::TxBuilder::Simple)
            [builder.funding_tx, tx, nil, nil]
          else
            [builder.funding_tx, tx, builder.p2c_address, builder.payment_base]
          end
        end

        def builder_class
          case timestamp_type.to_sym
          when :simple
            Contract::Timestamp::TxBuilder::Simple
          when :trackable
            if prev_id
              Contract::Timestamp::TxBuilder::UpdatingTrackable
            else
              Contract::Timestamp::TxBuilder::Trackable
            end
          end
        end

        def update_trackable?
          trackable? && prev_id
        end

        def validate_prev
          validate_prev!
          true
        rescue Errors::PrevTimestampNotFound,
               Errors::PrevTimestampIsNotTrackable,
               Errors::UnnecessaryPrevTimestamp
          false
        end

        def validate_prev!
          if simple? && prev_id
            message = "The previous timestamp(id: #{prev_id}) must be nil in simple timestamp"
            errors.add(:prev_id, message)
            raise Errors::UnnecessaryPrevTimestamp, message
          end

          return unless update_trackable?

          unless prev
            message = "The previous timestamp(id: #{prev_id}) not found."
            errors.add(:prev_id, message)
            raise Errors::PrevTimestampNotFound, message
          end

          unless prev.trackable?
            message = "The previous timestamp(id: #{prev_id}) type must be trackable"
            errors.add(:prev_id, message)
            raise Errors::PrevTimestampIsNotTrackable, message
          end

          if new_record? && self.class.where(prev_id: prev_id).exists?
            message = "The previous timestamp(id: #{prev_id}) was already updated"
            errors.add(:prev_id, message)
            raise Errors::PrevTimestampAlreadyUpdated, message
          end
        end
      end
    end
  end
end
