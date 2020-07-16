module Glueby
  class Wallet
    autoload :AbstractWalletAdapter, 'glueby/wallet/abstract_wallet_adapter'
    autoload :TapyrusCoreWalletAdapter, 'glueby/wallet/tapyrus_core_wallet_adapter'
    autoload :Errors, 'glueby/wallet/errors'

    class << self
      attr_writer :wallet_adapter

      def create
        new(wallet_adapter.create_wallet)
      end

      def load(wallet_id)
        wallet_adapter.load_wallet(wallet_id)
        new(wallet_id)
      end

      def wallets
        wallet_adapter.wallets.map { |id| new(id) }
      end

      def wallet_adapter
        if @wallet_adapter.nil?
          raise Errors::ShouldInitializeWalletAdapter, 'You should initialize wallet adapter using `Glueby::Wallet.wallet_adapter = some wallet adapter instance`.'
        end

        @wallet_adapter
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

    def sign_tx(tx)
      wallet_adapter.sign_tx(id, tx)
    end

    def receive_address
      wallet_adapter.receive_address(id)
    end

    def change_address
      wallet_adapter.change_address(id)
    end

    def pubkey
      wallet_adapter.pubkey(id)
    end

    private

    def wallet_adapter
      self.class.wallet_adapter
    end
  end
end