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
          # @param [Array] prevtxs array of outputs
          def sign(tx, prevtxs = [])
            tx.inputs.each.with_index do |input, index|
              script_pubkey = script_for_input(input, prevtxs)
              next unless script_pubkey
              key = Key.key_for_script(script_pubkey)
              next unless key
              sign_tx_for_p2pkh(tx, index, key, script_pubkey)
            end
            tx
          end

          def utxos
            Glueby::Internal::Wallet::AR::Utxo.where(key: keys)
          end

          private

          def sign_tx_for_p2pkh(tx, index, key, script_pubkey)
            sighash = tx.sighash_for_input(index, script_pubkey)
            sig = key.sign(sighash) + [Tapyrus::SIGHASH_TYPE[:all]].pack('C')
            script_sig = Tapyrus::Script.parse_from_payload(Tapyrus::Script.pack_pushdata(sig) + Tapyrus::Script.pack_pushdata(key.public_key.htb))
            tx.inputs[index].script_sig = script_sig
          end

          def script_for_input(input, prevtxs = [])
            out_point = input.out_point
            utxo = Utxo.find_by(txid: out_point.txid, index: out_point.index)
            if utxo
              Tapyrus::Script.parse_from_payload(utxo.script_pubkey.htb)
            else
              output = prevtxs.select { |output| output[:txid] == out_point.txid && output[:vout] == out_point.index }.first
              Tapyrus::Script.parse_from_payload(output[:scriptPubKey].htb) if output
            end
          end
        end
      end
    end
  end
end
