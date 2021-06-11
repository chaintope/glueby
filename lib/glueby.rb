require "glueby/version"
require 'tapyrus'

module Glueby
  autoload :Contract, 'glueby/contract'
  autoload :Generator, 'glueby/generator'
  autoload :Wallet, 'glueby/wallet'
  autoload :Internal, 'glueby/internal'
  autoload :AR, 'glueby/active_record'
  autoload :FeeProvider, 'glueby/fee_provider'
  autoload :Configuration, 'glueby/configuration'
  autoload :BlockSyncer, 'glueby/block_syncer'

  # Add prefix to activerecord table names
  def self.table_name_prefix
    'glueby_'
  end

  begin
    class Railtie < ::Rails::Railtie
      rake_tasks do
        load "tasks/glueby/contract.rake"
        load "tasks/glueby/contract/timestamp.rake"
        load "tasks/glueby/contract/wallet_adapter.rake"
        load "tasks/glueby/contract/block_syncer.rake"
        load "tasks/glueby/fee_provider.rake"
      end
    end
  rescue
    # Rake task is unavailable
    puts "Rake task is unavailable"
  end

  # Returns the global [Configuration](RSpec/Core/Configuration) object.
  def self.configuration
    @configuration ||= Glueby::Configuration.new
  end

  # Yields the global configuration to a block.
  # @yield [Configuration] global configuration
  #
  # @example
  #     Glueby.configure do |config|
  #       config.wallet_adapter = :activerecord
  #       config.rpc_config = { schema: 'http', host: '127.0.0.1', port: 12381, user: 'user', password: 'pass' }
  #     end
  def self.configure
    yield configuration if block_given?
  end
end
