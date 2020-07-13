module Glueby
  class Wallet
    autoload :AbstractWalletAdapter, 'glueby/wallet/abstract_wallet_adapter'
    autoload :TapyrusCoreWalletAdapter, 'glueby/wallet/tapyrus_core_wallet_adapter'
    autoload :Errors, 'glueby/wallet/errors'
  end
end