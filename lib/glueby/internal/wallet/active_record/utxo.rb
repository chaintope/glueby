# frozen_string_literal: true

module Glueby
  module Internal
    class Wallet
      module AR
        class Utxo < ::ActiveRecord::Base
          belongs_to :key

          enum status: { init: 0, broadcasted: 1, finalized: 2 }

          def color_id
            script = Tapyrus::Script.parse_from_payload(script_pubkey.htb)
            if script.cp2pkh? || script.cp2sh?
              Tapyrus::Color::ColorIdentifier.parse_from_payload(script.chunks[0].pushed_data).to_hex
            end
          end
        end
      end
    end
  end
end
