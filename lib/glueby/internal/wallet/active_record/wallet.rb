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
          # @param [Integer] sighashtype
          def sign(tx, prevtxs = [], sighashtype: Tapyrus::SIGHASH_TYPE[:all])
            validate_sighashtype!(sighashtype)

            tx.inputs.each.with_index do |input, index|
              script_pubkey = script_for_input(input, prevtxs)
              next unless script_pubkey
              key = keys.key_for_script(script_pubkey)
              next unless key
              sign_tx_for_p2pkh(tx, index, key, script_pubkey, sighashtype)
            end
            tx
          end

          def utxos
            Glueby::Internal::Wallet::AR::Utxo.where(key: keys)
          end

          def tokens(color_id = Tapyrus::Color::ColorIdentifier.default)
            utxos.where("lower(script_pubkey) like ?", "21#{color_id.to_hex}%")
          end

          private

          def sign_tx_for_p2pkh(tx, index, key, script_pubkey, sighashtype)
            sighash = tx.sighash_for_input(index, script_pubkey, hash_type: sighashtype)
            sig = key.sign(sighash) + [sighashtype].pack('C')
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

          def validate_sighashtype!(sighashtype)
            hash_type = sighashtype & (~(Tapyrus::SIGHASH_TYPE[:anyonecanpay]))
            if hash_type < Tapyrus::SIGHASH_TYPE[:all] || hash_type > Tapyrus::SIGHASH_TYPE[:single]
              raise Errors::InvalidSighashType, "Invalid sighash type '#{sighashtype}'"
            end
          end
        end
      end
    end
  end
end
