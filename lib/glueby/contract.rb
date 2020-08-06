module Glueby
  module Contract
    autoload :Errors, 'glueby/contract/errors'
    autoload :FeeProvider, 'glueby/contract/fee_provider'
    autoload :FixedFeeProvider, 'glueby/contract/fee_provider'
    autoload :Timestamp, 'glueby/contract/timestamp'
    autoload :TxBuilder, 'glueby/contract/tx_builder'
    autoload :WalletFeature, 'glueby/contract/wallet_feature'
    autoload :AR, 'glueby/contract/active_record'
  end
end
