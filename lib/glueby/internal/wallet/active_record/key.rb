# frozen_string_literal: true

module Glueby
  module Internal
    class Wallet
      module AR
        class Key < ::ActiveRecord::Base
          before_create :generate_key
          before_create :set_script_pubkey

          belongs_to :wallet

          enum :purpose, { receive: 0, change: 1 }

          validates :purpose, presence: true
          validates :private_key, uniqueness: { case_sensitive: false }

          def to_p2pkh
            Tapyrus::Script.to_p2pkh(Tapyrus.hash160(public_key))
          end

          def sign(data)
            Tapyrus::Key.new(priv_key: self.private_key, key_type: Tapyrus::Key::TYPES[:compressed]).sign(data, algo: :schnorr)
          end

          def address
            to_p2pkh.addresses.first
          end

          # Return Glueby::Internal::Wallet::AR::Key object for output.
          # If output is colored output, key is found by corresponding `uncolored` script.
          #
          # @param [Tapyrus::TxOut] output
          # @return [Glueby::Internal::Wallet::AR::Key] key for output
          def self.key_for_output(output)
            key_for_script(output.script_pubkey)
          end

          # Return Glueby::Internal::Wallet::AR::Key object for script.
          # If script is colored, key is found by corresponding `uncolored` script.
          #
          # @param [Tapyrus::Script] script_pubkey
          # @return [Glueby::Internal::Wallet::AR::Key] key for input
          def self.key_for_script(script_pubkey)
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
              Tapyrus::Key.new(priv_key: private_key, key_type: Tapyrus::Key::TYPES[:compressed])
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
