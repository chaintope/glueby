module Glueby
  module Contract
    # Timestamp feature allows users to send transaction with op_return output which has sha256 hash of arbitary data.
    # Timestamp transaction has
    # * 1 or more inputs enough to afford transaction fee.
    # * 1 output which has op_return, application specific prefix, and sha256 hash of data.
    # * 1 output to send the change TPC back to the wallet.
    #
    # Storing timestamp transaction to the blockchain enables everyone to verify that the data existed at that time and a user signed it.
    class Timestamp
      include Glueby::Contract::TxBuilder
      
      P2C_DEFAULT_VALUE = 1_000

      autoload :Syncer, 'glueby/contract/timestamp/syncer'

      module Util
        include Glueby::Internal::Wallet::TapyrusCoreWalletAdapter::Util
        module_function

        # @param [Glueby::Wallet] wallet
        # @param [Array] contents The data to be used for generating pay-to-contract address
        # @return [pay-to-contract address, public key used for generating address]
        def create_pay_to_contract_address(wallet, contents: nil)
          pubkey = wallet.internal_wallet.create_pubkey.pubkey
          # Calculate P + H(P || contents)G
          group = ECDSA::Group::Secp256k1
          p = Tapyrus::Key.new(pubkey: pubkey).to_point # P
          commitment = Tapyrus.sha256(p.to_hex(true).htb + contents.join).bth.to_i(16) % group.order # H(P || contents)
          point = p + group.generator.multiply_by_scalar(commitment) # P + H(P || contents)G
          [Tapyrus::Key.new(pubkey: point.to_hex(true)).to_p2pkh, pubkey] # [p2c address, P]
        end

        def create_txs(wallet, prefix, data, fee_estimator, utxo_provider, type: :simple)
          txb = Tapyrus::TxBuilder.new
          if type == :simple
            txb.data(prefix + data)
          elsif type == :trackable
            p2c_address, payment_base = create_pay_to_contract_address(wallet, contents: [prefix, data])
            txb.pay(p2c_address, P2C_DEFAULT_VALUE)
          end

          fee = fee_estimator.fee(dummy_tx(txb.build))
          if utxo_provider
            script_pubkey = Tapyrus::Script.parse_from_addr(wallet.internal_wallet.receive_address)
            funding_tx, index = utxo_provider.get_utxo(script_pubkey, fee)
            txb.add_utxo({
              script_pubkey: funding_tx.outputs[index].script_pubkey,
              txid: funding_tx.txid,
              index: index,
              value: funding_tx.outputs[index].value
            })
          else
            sum, outputs = wallet.internal_wallet.collect_uncolored_outputs(fee)
            outputs.each do |utxo|
              txb.add_utxo({
                script_pubkey: Tapyrus::Script.parse_from_payload(utxo[:script_pubkey].htb),
                txid: utxo[:txid],
                index: utxo[:vout],
                value: utxo[:amount]
              })
            end
          end

          prev_txs = if funding_tx
            output = funding_tx.outputs.first
            [{
              txid: funding_tx.txid,
              vout: 0,
              scriptPubKey: output.script_pubkey.to_hex,
              amount: output.value
            }]
          else
            []
          end

          txb.fee(fee).change_address(wallet.internal_wallet.change_address)
          [funding_tx, wallet.internal_wallet.sign_tx(txb.build, prev_txs), p2c_address, payment_base]
        end

        def get_transaction(tx)
          Glueby::Internal::RPC.client.getrawtransaction(tx.txid, 1)
        end

        def logger
          if defined?(Rails)
            Rails.logger
          else
            Logger.new(STDOUT)
          end
        end
      end
      include Glueby::Contract::Timestamp::Util

      attr_reader :tx, :txid

      # p2c_address and payment_base is used in `trackable` type
      attr_reader :p2c_address, :payment_base

      # @param [String] content Data to be hashed and stored in blockchain.
      # @param [String] prefix prefix of op_return data
      # @param [Glueby::Contract::FeeEstimator] fee_estimator
      # @param [Symbol] digest type which select of:
      # - :sha256
      # - :double_sha256
      # - :none
      # @param [Symbol] timestamp_type
      # - :simple
      # - :trackable
      # @raise [Glueby::Contract::Errors::UnsupportedDigestType] if digest is unsupported
      # @raise [Glueby::Contract::Errors::InvalidTimestampType] if timestamp_type is unsupported
      def initialize(
        wallet:,
        content:,
        prefix: '',
        fee_estimator: Glueby::Contract::FixedFeeEstimator.new,
        digest: :sha256,
        utxo_provider: nil,
        timestamp_type: :simple
      )
        @wallet = wallet
        @content = content
        @prefix = prefix
        @fee_estimator = fee_estimator
        raise Glueby::Contract::Errors::UnsupportedDigestType, "#{digest} is invalid digest, supported digest are :sha256, :double_sha256, and :none."  unless [:sha256, :double_sha256, :none].include?(digest)
        @digest = digest
        @utxo_provider = utxo_provider
        raise Glueby::Contract::Errors::InvalidTimestampType, "#{timestamp_type} is invalid type, supported types are :simple, and :trackable." unless [:simple, :trackable].include?(timestamp_type)
        @timestamp_type = timestamp_type
      end

      # broadcast to Tapyrus Core
      # @return [String] txid
      # @raise [TxAlreadyBroadcasted] if tx has been broadcasted.
      # @raise [InsufficientFunds] if result of listunspent is not enough to pay the specified amount
      def save!
        raise Glueby::Contract::Errors::TxAlreadyBroadcasted if @txid

        funding_tx, @tx, @p2c_address, @payment_base = create_txs(@wallet, @prefix, digest_content, @fee_estimator, @utxo_provider, type: @timestamp_type)
        @wallet.internal_wallet.broadcast(funding_tx) if funding_tx
        @txid = @wallet.internal_wallet.broadcast(@tx)
      end

      private

      def digest_content
        case @digest&.downcase
        when :sha256
          Tapyrus.sha256(@content)
        when :double_sha256
          Tapyrus.double_sha256(@content)
        when :none
          @content
        else
          raise Glueby::Contract::Errors::UnsupportedDigestType
        end
      end
    end
  end
end
