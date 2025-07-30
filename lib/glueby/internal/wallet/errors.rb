module Glueby
  module Internal
    class Wallet
      module Errors
        class ShouldInitializeWalletAdapter < Error; end
        class WalletUnloaded < Error; end
        class WalletAlreadyLoaded < Error; end
        class WalletAlreadyCreated < Error; end
        class WalletNotFound < Error; end
        class InvalidSighashType < Error; end
        class InvalidSigner < Error; end
        class PrivateKeyAlreadyImported < Error; end
      end
    end
  end
end
