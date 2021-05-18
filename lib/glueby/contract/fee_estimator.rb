module Glueby
  module Contract
    module FeeEstimator
      # @return fee by tapyrus(not TPC).
      def fee(_tx); end
    end

    class FixedFeeEstimator
      include FeeEstimator

      def initialize(fixed_fee: 10_000)
        @fixed_fee = fixed_fee
      end

      # @return fee by tapyrus(not TPC).
      def fee(_tx)
        @fixed_fee
      end
    end
  end
end
