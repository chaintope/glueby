module Glueby
  # Global configuration on runtime
  #
  # The global configuration treats configurations for all modules in Glueby.
  #
  # @example
  #     Glueby.configure do |config|
  #       config.wallet_adapter = :activerecord
  #       config.rpc_config = { schema: 'http', host: '127.0.0.1', port: 12381, user: 'user', password: 'pass' }
  #     end
  class Configuration

    attr_reader :fee_provider_bears, :use_utxo_provider
    alias_method :fee_provider_bears?, :fee_provider_bears
    alias_method :use_utxo_provider?, :use_utxo_provider

    def initialize
      @fee_provider_bears = false
      @use_utxo_provider = false
    end

    # Specify wallet adapter.
    # @param [Symbol] adapter - The adapter type :activerecord or :core is currently supported.
    def wallet_adapter=(adapter)
      case adapter
      when :core
        Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::TapyrusCoreWalletAdapter.new
      when :activerecord
        Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new
      else
        raise 'Not implemented'
      end
    end

    # Specify connection information to Tapyrus Core RPC.
    # @param [Hash] config
    # @option config [String] :schema - http or https
    # @option config [String] :host - The host of the RPC endpoint
    # @option config [Integer] :port - The port of the RPC endpoint
    # @Option config [String] :user - The user for Basic Authorization of the RPC endpoint
    # @Option config [String] :password - The password for Basic Authorization of the RPC endpoint
    def rpc_config=(config)
      Glueby::Internal::RPC.configure(config)
    end

    # Use This to enable to use FeeProvider to supply inputs for fees on each transaction that is created on Glueby.
    def fee_provider_bears!
      @fee_provider_bears = true
    end

    # Use This to disable to use FeeProvider
    def disable_fee_provider_bears!
      @fee_provider_bears = false
    end

    # Specify FeeProvider configuration.
    # @param [Hash] config
    # @option config [Integer] :fixed_fee - The fee that Fee Provider pays on each transaction.
    # @option config [Integer] :utxo_pool_size - Fee Provider tries to keep the number of utxo in utxo pool as this size using `glueby:fee_provider:manage_utxo_pool` rake task
    def fee_provider_config=(config)
      FeeProvider.configure(config)
    end

    # Enable UtxoProvider feature
    def enable_utxo_provider!
      @use_utxo_provider = true
    end

    # Disable UtxoProvider feature
    def disable_utxo_provider!
      @use_utxo_provider = false
    end
  end
end