module Tapyrus
  module Contract
    module TxBuilder
      # collect outputs in results so that sum of them exceeds up to the specified amount.
      # @param [Array] results of listunspent
      # @param [Numeric] amount
      # @return [(Numeric, Array)] sum value of outputs and outputs
      # @raise [InsufficientFunds] if result of listunspent is not enough to pay the specified amount
      def collect_outputs(results, amount)
        results.inject([0, []]) do |sum, output|
          new_sum = sum[0] + (output['amount'] * 100_000_000)
          new_outputs = sum[1] << output
          return [new_sum, new_outputs] if new_sum >= amount

          [new_sum, new_outputs]
        end
        raise Tapyrus::Contract::Errors::InsufficientFunds
      end

      # Add inputs to tx
      # @param [Tapyrus::Tx] tx
      # @param [Array] outputs provided as result of listunspent and extracted by #collect_outputs methods
      # @return [Tapyrus::Tx] tx which has enough amount in inputs.
      def fill_input(tx, outputs)
        outputs.each do |output|
          out_point = Tapyrus::OutPoint.new(output['txid'].rhex, output['vout'])
          tx.inputs << Tapyrus::TxIn.new(out_point: out_point)
        end
        tx
      end

      # Add output to tx, so that allow tx to return the change of the transaction.
      # @param [Tapyrus::Tx] tx
      # @param [Numeric] fee
      # @param [Tapyrus::Script] script for change
      # @param [Numeric] sum value of inputs
      def fill_change_output(tx, fee, change_script, sum)
        amount = fee + tx.outputs.map(&:value).sum
        if amount.positive?
          change = sum - amount
          tx.outputs << Tapyrus::TxOut.new(value: change, script_pubkey: change_script)
        end
        tx
      end
    end
  end
end
