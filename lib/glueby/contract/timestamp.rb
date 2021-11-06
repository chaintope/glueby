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

      autoload :Syncer, 'glueby/contract/timestamp/syncer'

      module Util
        include Glueby::Internal::Wallet::TapyrusCoreWalletAdapter::Util
        module_function

        def create_txs(wallet, prefix, data, fee_estimator, utxo_provider)
          txb = Tapyrus::TxBuilder.new
          txb.data(prefix + data)
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

          txb.fee(fee).change_address(wallet.internal_wallet.change_address)
          [funding_tx, wallet.internal_wallet.sign_tx(txb.build)]
        end

        def get_transaction(tx)
          Glueby::Internal::RPC.client.getrawtransaction(tx.txid, 1)
        end
      end
      include Glueby::Contract::Timestamp::Util

      attr_reader :tx, :txid

      # @param [String] content Data to be hashed and stored in blockchain.
      # @param [String] prefix prefix of op_return data
      # @param [Glueby::Contract::FeeEstimator] fee_estimator
      # @param [Symbol] digest type which select of:
      # - :sha256
      # - :double_sha256
      # - :none
      # @raise [Glueby::Contract::Errors::UnsupportedDigestType] if digest unsupport
      def initialize(
        wallet:,
        content:,
        prefix: '',
        fee_estimator: Glueby::Contract::FixedFeeEstimator.new,
        digest: :sha256,
        utxo_provider: nil
      )
        @wallet = wallet
        @content = content
        @prefix = prefix
        @fee_estimator = fee_estimator
        @digest = digest
        @utxo_provider = utxo_provider
      end

      # broadcast to Tapyrus Core
      # @return [String] txid
      # @raise [TxAlreadyBroadcasted] if tx has been broadcasted.
      # @raise [InsufficientFunds] if result of listunspent is not enough to pay the specified amount
      def save!
        raise Glueby::Contract::Errors::TxAlreadyBroadcasted if @txid

        funding_tx, @tx = create_txs(@wallet, @prefix, digest_content, @fee_estimator, @utxo_provider)
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
