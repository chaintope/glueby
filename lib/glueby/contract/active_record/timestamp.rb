module Glueby
  module Contract
    module AR
      class Timestamp < ::ActiveRecord::Base
        include Glueby::Contract::Timestamp::Util
        include Glueby::Contract::TxBuilder
        enum status: { init: 0, unconfirmed: 1, confirmed: 2 }
        enum timestamp_type: { simple: 0, trackable: 1 }

        # @param [Hash] attributes attributes which consist of:
        # - wallet_id
        # - content
        # - prefix(optional)
        # - timestamp_type(optional)
        def initialize(attributes = nil)
          @content_hash = Tapyrus.sha256(attributes[:content]).bth
          super(wallet_id: attributes[:wallet_id], content_hash: @content_hash,
                prefix: attributes[:prefix] ? attributes[:prefix] : '', status: :init, timestamp_type: attributes[:timestamp_type] || :simple)
        end

        # Return true if timestamp type is 'trackable' and output in timestamp transaction has not been spent yet, otherwise return false.
        def latest
          trackable?
        end

        # Broadcast and save timestamp
        # @param [Glueby::Contract::FixedFeeEstimator] fee estimator
        # @return true if tapyrus transactions were broadcasted and the timestamp was updated successfully, otherwise false.
        def save_with_broadcast(fee_estimator: Glueby::Contract::FixedFeeEstimator.new)
          utxo_provider = Glueby::UtxoProvider.new if Glueby.configuration.use_utxo_provider?
          wallet = Glueby::Wallet.load(wallet_id)
          funding_tx, tx, p2c_address, payment_base = create_txs(wallet, prefix, content_hash, fee_estimator, utxo_provider, type: timestamp_type.to_sym)
          if funding_tx
            ::ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
              wallet.internal_wallet.broadcast(funding_tx)
              logger.info("funding tx was broadcasted(id=#{id}, funding_tx.txid=#{funding_tx.txid})")
            end
          end
          ::ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
            wallet.internal_wallet.broadcast(tx) do |tx|
              assign_attributes(txid: tx.txid, status: :unconfirmed, p2c_address: p2c_address, payment_base: payment_base)
              save!
            end
            logger.info("timestamp tx was broadcasted (id=#{id}, txid=#{tx.txid})")
          end
          true
        rescue => e
          logger.error("failed to broadcast (id=#{id}, reason=#{e.message})")
          errors.add(:base, "failed to broadcast (id=#{id}, reason=#{e.message})")
          false
        end
      end
    end
  end
end
