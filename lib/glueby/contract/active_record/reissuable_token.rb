module Glueby
  module Contract
    module AR
      class ReissuableToken < ::ActiveRecord::Base

        def self.script_pubkey(color_id)
          Glueby::Contract::AR::ReissuableToken.where(color_id: color_id).pluck(:script_pubkey).first
        end

        def self.saved?(color_id)
          Glueby::Contract::AR::ReissuableToken.where(color_id: color_id).exists?
        end

      end
    end
  end
end
