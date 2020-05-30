module Tapyrus
  module Contract
    module WalletFeature
      def self.included(base)
        base.extend(ClassMethods)
      end
 
      def to_p2pkh
        Tapyrus::Script.to_p2pkh(key.hash160).to_payload
      end

      def address
        Tapyrus::Script.to_p2pkh(key.hash160).addresses.first
      end

      def key
        @key ||= Tapyrus::Key.generate
      end

      def key=(key)
        @key = key
      end

      module ClassMethods
        def from_wif(wif)
          new.tap { |wallet| wallet.key = Tapyrus::Key.from_wif(wif) }
        end
      end
    end
  end
end
