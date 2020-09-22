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

          def to_p2pkh
            Tapyrus::Script.to_p2pkh(Tapyrus.hash160(public_key))
          end

          def sign(data)
            Tapyrus::Key.new(priv_key: self.private_key).sign(data)
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
