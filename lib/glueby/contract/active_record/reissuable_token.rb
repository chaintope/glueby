module Glueby
  module Contract
    module AR
      class ReissuableToken < ::ActiveRecord::Base

        def self.script_pubkey(color_id)
          ReissuableToken.find_by(color_id: color_id)
        end

        def self.saved?(color_id)
          token = Glueby::Contract::AR::ReissuableToken.where(color_id: color_id)
          token.empty?
        end

      end
    end
  end
end
