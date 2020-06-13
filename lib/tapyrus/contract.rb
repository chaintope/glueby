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
    autoload :ActiveRecord,  'tapyrus/contract/active_record'

    begin
      class Railtie < ::Rails::Railtie
        rake_tasks do
          load "tasks/tapyrus/contract.rake"
          load "tasks/tapyrus/contract/timestamp.rake"
        end
      end
    rescue
      # Rake task is unavailable
      puts "Rake task is unavailable"
    end  
  end
end
