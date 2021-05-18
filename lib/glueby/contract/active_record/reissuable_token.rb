module Glueby
  module Contract
    module AR
      class ReissuableToken < ::ActiveRecord::Base

        def self.script_pubkey(color_id)
          ReissuableToken.find_by(color_id: color_id)
        end

      end
    end
  end
end
