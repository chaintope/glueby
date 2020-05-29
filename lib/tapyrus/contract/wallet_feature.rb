module Tapyrus
  module Contract
    module WalletFeature
      def to_p2pkh
        Tapyrus::Script.to_p2pkh(key.hash160).to_payload
      end

      def address
        Tapyrus::Script.to_p2pkh(key.hash160).addresses.first
      end

      def key
        @key ||= Tapyrus::Key.generate
      end
    end
  end
end
