# frozen_string_literal: true

module Glueby
  module Internal
    class Wallet
      module AR
        class Utxo < ::ActiveRecord::Base
          belongs_to :key

          validates :txid, uniqueness: { scope: :index, case_sensitive: false }

          enum status: { init: 0, broadcasted: 1, finalized: 2 }

          def color_id
            script = Tapyrus::Script.parse_from_payload(script_pubkey.htb)
            script.color_id&.to_hex
          end

          # Delete utxo spent by specified tx.
          #
          # @param [Tapyrus::Tx] the spending tx
          def self.destroy_for_inputs(tx)
            tx.inputs.each do |input|
              Glueby::Internal::Wallet::AR::Utxo.destroy_by(txid: input.out_point.txid, index: input.out_point.index)
            end
          end

          # Create utxo for tx outputs
          # if there is no key for script pubkey in an output, utxo for the output is not created.
          #
          # @param [Tapyrus::Tx] tx
          def self.create_for_outputs(tx, status: :finalized)
            tx.outputs.each.with_index do |output, index|
              key = Glueby::Internal::Wallet::AR::Key.key_for_output(output)
              next unless key

              Glueby::Internal::Wallet::AR::Utxo.create(
                txid: tx.txid,
                index: index,
                script_pubkey: output.script_pubkey.to_hex,
                value: output.value,
                status: status,
                key: key
              )
            end
          end
        end
      end
    end
  end
end
