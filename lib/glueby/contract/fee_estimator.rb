module Glueby
  module Contract
    module FeeEstimator
      autoload :Fixed, 'glueby/contract/fee_estimator/fixed'
      autoload :Auto, 'glueby/contract/fee_estimator/auto'

      # @param [Tapyrus::Tx] tx - The target tx
      # @return fee by tapyrus(not TPC).
      def fee(tx)
        return 0 if Glueby.configuration.fee_provider_bears?
        estimate_fee(tx)
      end

      # Add dummy inputs and outputs to tx
      def dummy_tx(tx)
        dummy = Tapyrus::Tx.parse_from_payload(tx.to_payload)

        # dummy input for tpc
        out_point = Tapyrus::OutPoint.new('00' * 32, 0)
        dummy.inputs << Tapyrus::TxIn.new(out_point: out_point)

        # Add script_sig to all intpus
        dummy.inputs.each do |input|
          input.script_sig = Tapyrus::Script.parse_from_payload(('00' * 100).htb)
        end

        # dummy output to return change
        change_script = Tapyrus::Script.to_p2pkh('0000000000000000000000000000000000000000')
        dummy.outputs << Tapyrus::TxOut.new(value: 0, script_pubkey: change_script)
        dummy
      end
      module_function :dummy_tx

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
