module Glueby
  module Contract
    module FeeEstimator
      # @param [Tapyrus::Tx] tx - The target tx
      # @return fee by tapyrus(not TPC).
      def fee(tx)
        return 0 if Glueby.configuration.fee_provider_bears?
        estimate_fee(tx)
      end

      private

      # @private
      # @abstract Override in subclasses. This is would be implemented an actual estimation logic.
      # @param [Tapyrus::Tx] tx - The target tx
      # @return fee by tapyrus(not TPC).
      def estimate_fee(tx)
        raise NotImplementedError
      end
    end

    class FixedFeeEstimator
      include FeeEstimator

      attr_reader :fixed_fee

      class << self
        attr_accessor :default_fixed_fee
      end

      def initialize(fixed_fee: FixedFeeEstimator.default_fixed_fee || 10_000)
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
