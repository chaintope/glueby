module Glueby
  module Contract
    module FeeEstimator
      class Fixed
        include FeeEstimator

        # Default fee in tapyrus that is used if it is not configured
        DEFAULT_FEE = 10_000

        attr_reader :fixed_fee

        class << self
          attr_accessor :default_fixed_fee
        end

        def initialize(fixed_fee: Fixed.default_fixed_fee || DEFAULT_FEE)
          @fixed_fee = fixed_fee
        end

        private

        # @private
        # @return fee by tapyrus(not TPC).
        def estimate_fee(_tx)
          @fixed_fee
        end
      end
    end
  end
end