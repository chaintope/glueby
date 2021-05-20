module Glueby
  module Internal
    class Wallet
      module Errors
        class ShouldInitializeWalletAdapter < StandardError; end
        class WalletUnloaded < StandardError; end
        class WalletAlreadyLoaded < StandardError; end
        class WalletAlreadyCreated < StandardError; end
        class InvalidSighashType < StandardError; end
      end
    end
  end
end
