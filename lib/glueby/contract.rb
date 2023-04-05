module Glueby
  module Contract
    autoload :Errors, 'glueby/contract/errors'
    autoload :FeeEstimator, 'glueby/contract/fee_estimator'
    autoload :FixedFeeEstimator, 'glueby/contract/fee_estimator'
    autoload :Payment, 'glueby/contract/payment'
    autoload :Timestamp, 'glueby/contract/timestamp'
    autoload :Token, 'glueby/contract/token'
    autoload :TxBuilder, 'glueby/contract/tx_builder'
    autoload :AR, 'glueby/contract/active_record'
  end
end
