module Tapyrus
  module Contract
    module AR
      class Account < ::ActiveRecord::Base
        has_many :addresses, -> { order(:address_index) }
      end
    end
  end
end
