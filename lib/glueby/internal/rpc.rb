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

      def switch_wallet(wallet)
        before = client.config[:wallet]
        client.config[:wallet] = wallet
        result = yield(client)
        client.config[:wallet] = before
        result
      end
    end
  end
end
