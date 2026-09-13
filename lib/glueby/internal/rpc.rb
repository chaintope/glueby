module Glueby
  module Internal
    module RPC
      # Guards the shared client so that building it and replacing the config do not overlap. Without it, a
      # client built from a config that configure has already replaced could still be stored afterwards, and
      # threads that start at the same time could each build their own.
      CLIENT_MUTEX = Mutex.new
      private_constant :CLIENT_MUTEX

      module_function

      def client
        @rpc || CLIENT_MUTEX.synchronize { @rpc ||= Tapyrus::RPC::TapyrusCoreClient.new(@config) }
      end

      def configure(config)
        CLIENT_MUTEX.synchronize do
          @config = config
          @rpc = nil
        end
      end

      # Perform RPC call on the specific wallet.
      # This method needs block, and pass a client as a block argument. You can call RPCs on the wallet using the
      # client object. See an example below.
      #
      # The client is dedicated to the given wallet and is never shared with other callers, so calls on different
      # wallets do not interfere with each other. Its config is frozen.
      #
      # @param [string] wallet name on Tapyrus Core Wallet
      # @return [Object] The return object of the block
      #
      # ## Example
      # ```ruby
      # perform_as('mywallet') do |client|
      #   client.getbalance
      # end
      # ```
      def perform_as(wallet)
        yield(wallet_client(wallet))
      end

      # Returns a client that sends its requests to /wallet/<wallet>.
      #
      # It copies the shared client instead of building a new one. TapyrusCoreClient#initialize issues a `help`
      # RPC, and Tapyrus Core answers it with RPC_WALLET_NOT_FOUND when the wallet is not loaded. Building a
      # client here would raise that error before the caller's own RPC runs, where the caller cannot tell it
      # apart from a failure of the RPC it asked for.
      def wallet_client(wallet)
        shared = client
        shared.dup.tap do |dedicated|
          dedicated.instance_variable_set(:@config, shared.config.merge(wallet: wallet).freeze)
        end
      end
      private_class_method :wallet_client
    end
  end
end
