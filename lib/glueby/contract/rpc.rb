module Glueby
  module Contract
    module RPC
      module_function

      def client
        @rpc
      end

      def configure(config)
        @rpc = Tapyrus::RPC::TapyrusCoreClient.new(config)
      end
    end
  end
end
