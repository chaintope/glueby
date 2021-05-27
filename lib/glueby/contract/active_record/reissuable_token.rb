module Glueby
  module Contract
    module AR
      class ReissuableToken < ::ActiveRecord::Base

        # Get the script_pubkey corresponding to the color_id in Tapyrus::Script format
        # @param [String] color_id
        # @return [Tapyrus::Script]
        def self.script_pubkey(color_id)
          script_pubkey = Glueby::Contract::AR::ReissuableToken.where(color_id: color_id).pluck(:script_pubkey).first
          if script_pubkey
            Tapyrus::Script.parse_from_payload(script_pubkey.htb)
          end
        end

        # Check if the color_id is already stored
        # @param [String] color_id
        # @return [Boolean]
        def self.saved?(color_id)
          Glueby::Contract::AR::ReissuableToken.where(color_id: color_id).exists?
        end

      end
    end
  end
end
