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
        end
      end
    end
  end
end
