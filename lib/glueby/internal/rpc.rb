module Glueby
  module Internal
    module RPC
      module_function

      def client
        @rpc ||= Tapyrus::RPC::TapyrusCoreClient.new(@config)
      end

      def configure(config)
        @config = config
      end

      # Perform RPC call on the specific wallet.
      # This method needs block, and pass a client as as block argument. You can call RPCs on the wallet using the
      # client object. See an example below.
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
        before = client.config[:wallet]
        client.config[:wallet] = wallet
        yield(client)
      ensure
        client.config[:wallet] = before
      end
    end
  end
end
