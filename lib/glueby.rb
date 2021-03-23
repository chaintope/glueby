require "glueby/version"
require 'tapyrus'

module Glueby
  autoload :Contract, 'glueby/contract'
  autoload :Generator, 'glueby/generator'
  autoload :Wallet, 'glueby/wallet'
  autoload :Internal, 'glueby/internal'
  autoload :AR, 'glueby/active_record'

  begin
    class Railtie < ::Rails::Railtie
      rake_tasks do
        load "tasks/glueby/contract.rake"
        load "tasks/glueby/contract/timestamp.rake"
        load "tasks/glueby/contract/wallet_adapter.rake"
        load "tasks/glueby/contract/block_syncer.rake"
      end
    end
  rescue
    # Rake task is unavailable
    puts "Rake task is unavailable"
  end
end
