# frozen_string_literal: true

module Glueby
  module Internal
    class Wallet
      module AR
        class Utxo < ::ActiveRecord::Base
          belongs_to :key

          validates :txid, uniqueness: { scope: :index, case_sensitive: false }
          validate :check_dust_output

          enum :status, { init: 0, broadcasted: 1, finalized: 2 }

          def color_id
            script = Tapyrus::Script.parse_from_payload(script_pubkey.htb)
            script.color_id&.to_hex
          end

          # Delete utxo spent by specified tx.
          #
          # @param [Tapyrus::Tx] the spending tx
          def self.destroy_for_inputs(tx)
            tx.inputs.each do |input|
              Utxo.destroy_by(txid: input.out_point.txid, index: input.out_point.index)
            end
          end

          # Create utxo or update utxo for tx outputs
          # if there is no key for script pubkey in an output, utxo for the output is not created.
          #
          # @param [Tapyrus::Tx] tx
          def self.create_or_update_for_outputs(tx, status: :finalized)
            tx.outputs.each.with_index do |output, index|
              key = Key.key_for_output(output)
              next unless key

              utxo = Utxo.find_or_initialize_by(txid: tx.txid, index: index)
              utxo.update!(
                label: key.label,
                color_id: output.script_pubkey.color_id&.to_hex,
                script_pubkey: output.script_pubkey.to_hex,
                value: output.value,
                status: status,
                key: key
              )
            end
          end

        private

          def check_dust_output
            output = Tapyrus::TxOut.new(value: value, script_pubkey: Tapyrus::Script.parse_from_payload(script_pubkey.htb))
            if !color_id && output.dust?
              errors.add(:value, "is less than dust limit(#{output.send(:dust_threshold)})")
            end
          end
        end
      end
    end
  end
end
