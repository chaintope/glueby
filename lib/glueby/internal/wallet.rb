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
      autoload :AR, 'glueby/internal/wallet/active_record'
      autoload :TapyrusCoreWalletAdapter, 'glueby/internal/wallet/tapyrus_core_wallet_adapter'
      autoload :ActiveRecordWalletAdapter, 'glueby/internal/wallet/active_record_wallet_adapter'
      autoload :Errors, 'glueby/internal/wallet/errors'

      include GluebyLogger

      class << self
        def create(wallet_id = nil)
          begin
            wallet_id = wallet_adapter.create_wallet(wallet_id)
          rescue Errors::WalletAlreadyCreated => _
            # Ignore when wallet is already created.
          end
          new(wallet_id)
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

        def wallet_adapter=(adapter)
          if adapter.is_a?(ActiveRecordWalletAdapter)
            BlockSyncer.register_syncer(ActiveRecordWalletAdapter::Syncer)
          else
            BlockSyncer.unregister_syncer(ActiveRecordWalletAdapter::Syncer)
          end

          @wallet_adapter = adapter
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

      # @param only_finalized [Boolean] The flag to get a UTXO with status only finalized
      # @param label [String] This label is used to filtered the UTXOs with labeled if a key or Utxo is labeled.
      #                    - If label is nil or :unlabeled, only unlabeled UTXOs will be returned.
      #                    - If label=:all, all UTXOs will be returned.
      def list_unspent(only_finalized = true, label = :unlabeled)
        label = :unlabeled unless label
        wallet_adapter.list_unspent(id, only_finalized, label)
      end

      def delete
        wallet_adapter.delete_wallet(id)
      end

      # @param [Tapyrus::Tx] tx The tx that is signed
      # @param [Array<Hash>] prev_txs An array of hash that represents unbroadcasted transaction outputs used by signing tx
      #   @option prev_txs [String] :txid
      #   @option prev_txs [Integer] :vout
      #   @option prev_txs [String] :scriptPubkey
      #   @option prev_txs [Integer] :amount
      # @param [Boolean] for_fee_provider_input The flag to notify whether the caller is FeeProvider and called for signing a input that is by FeeProvider.
      def sign_tx(tx, prev_txs = [], for_fee_provider_input: false)
        sighashtype = Tapyrus::SIGHASH_TYPE[:all]

        if !for_fee_provider_input && Glueby.configuration.fee_provider_bears?
          sighashtype |= Tapyrus::SIGHASH_TYPE[:anyonecanpay]
        end

        wallet_adapter.sign_tx(id, tx, prev_txs, sighashtype: sighashtype)
      end

      # Broadcast a transaction via Tapyrus Core RPC
      # @param [Tapyrus::Tx] tx The tx that would be broadcasted
      # @option [Boolean] without_fee_provider The flag to avoid to use FeeProvider temporary.
      # @param [Proc] block The block that is called before broadcasting. It can be used to handle tx that is modified by FeeProvider.
      def broadcast(tx, without_fee_provider: false, &block)
        tx = FeeProvider.provide(tx) if !without_fee_provider && Glueby.configuration.fee_provider_bears?
        logger.info("Try to broadcast a tx (tx payload: #{tx.to_hex} )")
        wallet_adapter.broadcast(id, tx, &block)
        tx
      end

      def receive_address(label = nil)
        wallet_adapter.receive_address(id, label)
      end

      def change_address
        wallet_adapter.change_address(id)
      end

      def create_pubkey
        wallet_adapter.create_pubkey(id)
      end

      def collect_uncolored_outputs(amount, label = nil, only_finalized = true, shuffle = false)
        utxos = list_unspent(only_finalized, label)
        utxos.shuffle! if shuffle

        utxos.inject([0, []]) do |sum, output|
          next sum if output[:color_id]

          new_sum = sum[0] + output[:amount]
          new_outputs = sum[1] << output
          return [new_sum, new_outputs] if new_sum >= amount

          [new_sum, new_outputs]
        end
        raise Glueby::Contract::Errors::InsufficientFunds
      end

      def get_addresses(label = nil)
        wallet_adapter.get_addresses(id, label)
      end

      def create_pay_to_contract_address(contents)
        wallet_adapter.create_pay_to_contract_address(id, contents)
      end

      def pay_to_contract_key(payment_base, contents)
        wallet_adapter.pay_to_contract_key(id, payment_base, contents)
      end

      def sign_to_pay_to_contract_address(tx, utxo, payment_base, contents)
        wallet_adapter.sign_to_pay_to_contract_address(id, tx, utxo, payment_base, contents)
      end

      def has_address?(address)
        wallet_adapter.has_address?(id, address)
      end

      private

      def wallet_adapter
        self.class.wallet_adapter
      end
    end
  end
end
