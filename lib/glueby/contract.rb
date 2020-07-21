module Glueby
  module Contract
    autoload :Errors, 'glueby/contract/errors'
    autoload :FeeProvider, 'glueby/contract/fee_provider'
    autoload :FixedFeeProvider, 'glueby/contract/fee_provider'
    autoload :Timestamp, 'glueby/contract/timestamp'
    autoload :TxBuilder, 'glueby/contract/tx_builder'
    autoload :WalletFeature, 'glueby/contract/wallet_feature'
    autoload :AR, 'glueby/contract/active_record'

    begin
      class Railtie < ::Rails::Railtie
        rake_tasks do
          load "tasks/glueby/contract.rake"
          load "tasks/glueby/contract/timestamp.rake"
        end
      end
    rescue
      # Rake task is unavailable
      puts "Rake task is unavailable"
    end  
  end
end
