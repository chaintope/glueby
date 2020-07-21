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

      def switch_wallet(wallet, &block)
        if block
          before = client.config[:wallet]
          client.config[:wallet] = wallet
          result = yield(client)
          client.config[:wallet] = before
          result
        else
          client.config[:wallet] = wallet
        end
      end
    end
  end
end
