module Tapyrus
  module Contract
    module FeeProvider
      # @return fee by tapyrus(not TPC).
      def fee(_tx); end
    end

    class FixedFeeProvider
      include FeeProvider

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
