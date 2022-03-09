module Glueby
  module Contract
    module FeeEstimator
      autoload :Fixed, 'glueby/contract/fee_estimator/fixed'
      autoload :Calc, 'glueby/contract/fee_estimator/calc'

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

    # Create alias name of FeeEstimator::Fixed class for backward compatibility
    FixedFeeEstimator = FeeEstimator::Fixed
  end
end
