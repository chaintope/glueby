# frozen_string_literal: true

module Glueby
  module Internal
    class Wallet
      module AR
        class Key < ::ActiveRecord::Base
          before_create :generate_key
          before_create :set_script_pubkey

          belongs_to :wallet

          enum purpose: { receive: 0, change: 1 }

          validates :purpose, presence: true
          validates :private_key, uniqueness: { case_sensitive: false }

          def to_p2pkh
            Tapyrus::Script.to_p2pkh(Tapyrus.hash160(public_key))
          end

          def sign(data)
            Tapyrus::Key.new(priv_key: self.private_key).sign(data, algo: :schnorr)
          end

          def address
            to_p2pkh.addresses.first
          end

          # Return Glueby::Internal::Wallet::AR::Key object for input.
          # If utxo spent by the specified input is colored output, key is found by corresponding `uncolored` script.
          #
          # @param [Tapyrus::TxIn] input
          # @return [Glueby::Internal::Wallet::AR::Key] key for input
          def self.key_for_input(input)
            out_point = input.out_point
            utxo = Glueby::Internal::Wallet::AR::Utxo.find_by(txid: out_point.txid, index: out_point.index)
            return unless utxo
            script_pubkey = Tapyrus::Script.parse_from_payload(utxo.script_pubkey.htb)
            script_pubkey = if script_pubkey.colored?
              script_pubkey.remove_color.to_hex
            else
              script_pubkey.to_hex
            end
            find_by(script_pubkey: script_pubkey)
          end

          private

          def generate_key
            key = if private_key
              Tapyrus::Key.new(priv_key: private_key)
            else
              Tapyrus::Key.generate
            end
            self.private_key ||= key.priv_key
            self.public_key ||= key.pubkey
          end

          def set_script_pubkey
            self.script_pubkey = to_p2pkh.to_hex
          end
        end
      end
    end
  end
end
