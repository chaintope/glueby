require "glueby/version"
require "glueby/constants"
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
  autoload :Util, 'glueby/util'
  autoload :UtxoProvider, 'glueby/utxo_provider'

  if defined? ::Rails::Railtie
    require 'glueby/railtie'
  end

  module GluebyLogger
    def logger
      if defined?(Rails)
        Rails.logger
      else
        Logger.new(STDOUT)
      end
    end
  end

  # Add prefix to activerecord table names
  def self.table_name_prefix
    'glueby_'
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

  # Base error classes. These error classes must be used as a super class in all error classes that is defined and
  # raised in glueby library.
  class Error < StandardError; end
  class ArgumentError < Error; end
end
