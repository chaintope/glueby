require "tapyrus/contract/version"

module Tapyrus
  module Contract
    autoload :Errors, 'tapyrus/contract/errors'
    autoload :FeeProvider, 'tapyrus/contract/fee_provider'
    autoload :FixedFeeProvider, 'tapyrus/contract/fee_provider'
    autoload :RPC, 'tapyrus/contract/rpc'
    autoload :Timestamp, 'tapyrus/contract/timestamp'
    autoload :TxBuilder, 'tapyrus/contract/tx_builder'
    autoload :WalletFeature, 'tapyrus/contract/wallet_feature'
  end
end
