module Glueby
  module Contract
    class Timestamp
      class TxBuilder

        # The simple Timestamp method
        class SimpleTxBuilder
          include Glueby::Contract::TxBuilder

          attr_reader :funding_tx

          def initialize(wallet, fee_estimator)
            @wallet = wallet
            @fee_estimator = fee_estimator

            @txb = Tapyrus::TxBuilder.new
            @prev_txs = []
          end

          def build
            @txb.fee(fee).change_address(@wallet.internal_wallet.change_address)
            sign_tx
          end

          def set_data(prefix, data)
            @prefix = prefix
            @data = data

            @txb.data(prefix + data)
            self
          end

          def set_inputs(utxo_provider)
            if utxo_provider
              script_pubkey = Tapyrus::Script.parse_from_addr(@wallet.internal_wallet.receive_address)
              @funding_tx, index = utxo_provider.get_utxo(script_pubkey, fee)

              utxo = {
                script_pubkey: @funding_tx.outputs[index].script_pubkey.to_hex,
                txid: @funding_tx.txid,
                vout: index,
                amount: funding_tx.outputs[index].value
              }

              @txb.add_utxo(to_tapyrusrb_utxo_hash(utxo))
              @prev_txs << to_sign_tx_utxo_hash(utxo)
            else
              _, outputs = @wallet.internal_wallet.collect_uncolored_outputs(fee)
              outputs.each do |utxo|
                @txb.add_utxo(to_tapyrusrb_utxo_hash(utxo))
              end
            end
            self
          end

          private

          def fee
            @fee ||= @fee_estimator.fee(dummy_tx(@txb.build))
          end

          def sign_tx
            # General signing process skips signing to p2c inputs because no key of the p2c address in the wallet.
            @wallet.internal_wallet.sign_tx(@txb.build, @prev_txs)
          end

          # @param utxo
          # @option utxo [String] :txid The txid
          # @option utxo [Integer] :vout The index of the output in the tx
          # @option utxo [Integer] :amount The value of the output
          # @option utxo [String] :script_pubkey The hex string of the script pubkey
          def to_tapyrusrb_utxo_hash(utxo)
            {
              script_pubkey: Tapyrus::Script.parse_from_payload(utxo[:script_pubkey].htb),
              txid: utxo[:txid],
              index: utxo[:vout],
              value: utxo[:amount]
            }
          end

          # @param utxo
          # @option utxo [String] :txid The txid
          # @option utxo [Integer] :vout The index of the output in the tx
          # @option utxo [Integer] :amount The value of the output
          # @option utxo [String] :script_pubkey The hex string of the script pubkey
          def to_sign_tx_utxo_hash(utxo)
            {
              scriptPubKey: utxo[:script_pubkey],
              txid: utxo[:txid],
              vout: utxo[:vout],
              amount: utxo[:amount]
            }
          end
        end
      end
    end
  end
end