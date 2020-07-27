module Glueby
  module Internal
    module RPC
      module_function

      def client
        @rpc
      end

      def configure(config)
        @rpc = Tapyrus::RPC::TapyrusCoreClient.new(config)
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
        result = yield(client)
        client.config[:wallet] = before
        result
      end
    end
  end
end
