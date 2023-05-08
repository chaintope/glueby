module Glueby
  module Contract
    class Timestamp
      module TxBuilder
        # The simple Timestamp method
        class Simple
          def initialize(wallet, fee_estimator)
            @wallet = wallet
            @fee_estimator = fee_estimator

            @txb = Internal::ContractBuilder.new(
              sender_wallet: @wallet.internal_wallet,
              fee_estimator: @fee_estimator
            )
          end

          def build
            @txb.build
          end

          def set_data(prefix, data)
            @prefix = prefix
            @data = data

            contents = [prefix, data].map do |content|
              content.bytes.map { |i| i.to_s(16) }.join
            end

            @txb.data(*contents)
            self
          end

          def set_inputs(utxo_provider)
            if utxo_provider
              @txb.add_utxo_to!(
                address: @wallet.internal_wallet.receive_address,
                amount: input_amount,
                utxo_provider: utxo_provider
              )
            else
              fee = input_amount
              return self if fee == 0

              _, outputs = @wallet.internal_wallet.collect_uncolored_outputs(fee)
              outputs.each { |utxo| @txb.add_utxo(utxo) }
            end
            self
          end

          def funding_tx
            @txb.prev_txs.first
          end

          private

          def input_amount
            @txb.dummy_fee
          end
        end
      end
    end
  end
end