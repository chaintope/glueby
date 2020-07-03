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

      module Util
        module_function

        def create_tx(prefix, data_hash, fee_provider)
          tx = Tapyrus::Tx.new
          tx.outputs << Tapyrus::TxOut.new(value: 0, script_pubkey: create_script(prefix, data_hash))
  
          results = list_unspent
          fee = fee_provider.fee(tx)
          sum, outputs = collect_outputs(results, fee)
          fill_input(tx, outputs)
  
          change_script = create_change_script
          fill_change_output(tx, fee, change_script, sum)
          tx
        end
  
        def create_payload(prefix, data_hash)
          payload = +''
          payload << prefix
          payload << data_hash
          payload
        end

        def create_script(prefix, data_hash)
          script = Tapyrus::Script.new
          script << Tapyrus::Script::OP_RETURN
          script << create_payload(prefix, data_hash)
          script
        end

        def create_change_script
          address = Glueby::Contract::RPC.client.getnewaddress
          decoded = Tapyrus.decode_base58_address(address)
          Tapyrus::Script.to_p2pkh(decoded[0])
        end

        def sign_tx(tx)
          # TODO: Implement SignatureProvider
          response = Glueby::Contract::RPC.client.signrawtransactionwithwallet(tx.to_payload.bth)
          Tapyrus::Tx.parse_from_payload(response['hex'].htb)
        end

        def list_unspent
          # TODO: Implement UtxoProvider
          Glueby::Contract::RPC.client.listunspent(0, 999_999)
        end

        def broadcast_tx(tx)
          Glueby::Contract::RPC.client.sendrawtransaction(tx.to_payload.bth)
        end

        def get_transaction(tx)
          Glueby::Contract::RPC.client.getrawtransaction(tx.txid, 1)
        end
      end
      include Glueby::Contract::Timestamp::Util

      attr_reader :tx, :txid

      # @param [String] content Data to be hashed and stored in blockchain.
      # @param [String] prefix prefix of op_return data
      # @param [Glueby::Contract::FeeProvider] fee_provider
      def initialize(
        content:,
        prefix: '',
        fee_provider: Glueby::Contract::FixedFeeProvider.new
      )
        @content = content
        @prefix = prefix
        @fee_provider = fee_provider
      end

      # broadcast to Tapyrus Core
      # @return [String] txid
      # @raise [TxAlreadyBroadcasted] if tx has been broadcasted.
      # @raise [InsufficientFunds] if result of listunspent is not enough to pay the specified amount
      def save!
        raise Glueby::Contract::Errors::TxAlreadyBroadcasted if @txid

        @tx = create_tx(@prefix, Tapyrus.sha256(@content), @fee_provider)
        @tx = sign_tx(@tx)
        @txid = broadcast_tx(@tx)
      end
    end
  end
end
