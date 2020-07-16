module Glueby
  class Wallet
    module Errors
      class ShouldInitializeWalletAdapter < StandardError; end
      class WalletUnloaded < StandardError; end
    end
  end
end
