module Glueby
  module Contract
    autoload :Errors, 'glueby/contract/errors'
    autoload :FeeProvider, 'glueby/contract/fee_provider'
    autoload :FixedFeeProvider, 'glueby/contract/fee_provider'
    autoload :Timestamp, 'glueby/contract/timestamp'
    autoload :Token, 'glueby/contract/token'
    autoload :TokenTxBuilder, 'glueby/contract/token_tx_builder'
    autoload :TxBuilder, 'glueby/contract/tx_builder'
    autoload :AR, 'glueby/contract/active_record'
    autoload :Wallet, 'glueby/contract/wallet'
  end
end
