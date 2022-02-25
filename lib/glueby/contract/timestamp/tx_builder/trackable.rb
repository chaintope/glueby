module Glueby
  module Contract
    class Timestamp
      module TxBuilder
        class Trackable < Simple
          attr_reader :p2c_address, :payment_base

          # @override
          def set_data(prefix, data)
            @prefix = prefix
            @data = data

            # Create a new trackable timestamp
            @p2c_address, @payment_base = @wallet.internal_wallet
                                                 .create_pay_to_contract_address([prefix, data].join)
            @txb.pay(p2c_address, P2C_DEFAULT_VALUE)
            self
          end
        end
      end
    end
  end
end