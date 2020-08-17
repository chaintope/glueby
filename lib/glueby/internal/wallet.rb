module Glueby
  module Internal
    # # Glueby::Internal::Wallet
    #
    # This module provides the way to deal about wallet that includes key management, address management, getting UTXOs.
    #
    # ## How to use
    #
    # First, you need to configure which wallet implementation is used in Glueby::Internal::Wallet. For now, below wallets are
    # supported.
    #
    # * [Tapyrus Core](https://github.com/chaintope/tapyrus-core)
    #
    # Here shows an example to use Tapyrus Core wallet.
    #
    # ```ruby
    # # Setup Tapyrus Core RPC connection
    # config = {schema: 'http', host: '127.0.0.1', port: 12381, user: 'user', password: 'pass'}
    # Glueby::Internal::RPC.configure(config)
    #
    # # Setup wallet adapter
    # Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::TapyrusCoreWalletAdapter.new
    #
    # # Create wallet
    # wallet = Glueby::Internal::Wallet.create
    # wallet.balance # => 0
    # wallet.list_unspent
    # ```
    class Wallet
      autoload :AbstractWalletAdapter, 'glueby/internal/wallet/abstract_wallet_adapter'
      autoload :TapyrusCoreWalletAdapter, 'glueby/internal/wallet/tapyrus_core_wallet_adapter'
      autoload :Errors, 'glueby/internal/wallet/errors'

      class << self
        attr_writer :wallet_adapter

        def create
          new(wallet_adapter.create_wallet)
        end

        def load(wallet_id)
          begin
            wallet_adapter.load_wallet(wallet_id)
          rescue Errors::WalletAlreadyLoaded => _
            # Ignore when wallet is already loaded.
          end
          new(wallet_id)
        end

        def wallets
          wallet_adapter.wallets.map { |id| new(id) }
        end

        def wallet_adapter
          @wallet_adapter or
            raise Errors::ShouldInitializeWalletAdapter, 'You should initialize wallet adapter using `Glueby::Internal::Wallet.wallet_adapter = some wallet adapter instance`.'
        end
      end

      attr_reader :id

      def initialize(wallet_id)
        @id = wallet_id
      end

      def balance(only_finalized = true)
        wallet_adapter.balance(id, only_finalized)
      end

      def list_unspent(only_finalized = true)
        wallet_adapter.list_unspent(id, only_finalized)
      end

      def delete
        wallet_adapter.delete_wallet(id)
      end

      def sign_tx(tx, prev_txs = [])
        wallet_adapter.sign_tx(id, tx, prev_txs)
      end

      def receive_address
        wallet_adapter.receive_address(id)
      end

      def change_address
        wallet_adapter.change_address(id)
      end

      def create_pubkey
        wallet_adapter.create_pubkey(id)
      end

      private

      def wallet_adapter
        self.class.wallet_adapter
      end
    end
  end
end
