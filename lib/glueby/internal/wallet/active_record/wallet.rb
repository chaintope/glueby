# frozen_string_literal: true

require 'active_record'

module Glueby
  module Internal
    class Wallet
      module AR
        class Wallet < ::ActiveRecord::Base
          has_many :keys

          validates :wallet_id, uniqueness: { case_sensitive: false }

          # @param [Tapyrus::Tx] tx
          def sign(tx)
            tx.inputs.each.with_index do |input, index|
              key = Key.key_for_input(input)
              next unless key
              sign_tx_for_p2pkh(tx, index, key)
            end
            tx
          end

          def utxos
            Glueby::Internal::Wallet::AR::Utxo.where(key: keys)
          end

          private

          def sign_tx_for_p2pkh(tx, index, key)
            sighash = tx.sighash_for_input(index, key.to_p2pkh)
            sig = key.sign(sighash) + [Tapyrus::SIGHASH_TYPE[:all]].pack('C')
            script_sig = Tapyrus::Script.parse_from_payload(Tapyrus::Script.pack_pushdata(sig) + Tapyrus::Script.pack_pushdata(key.public_key.htb))
            tx.inputs[index].script_sig = script_sig
          end
        end
      end
    end
  end
end
