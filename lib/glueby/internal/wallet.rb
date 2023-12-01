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
      autoload :MySQLWalletAdapter, 'glueby/internal/wallet/mysql_wallet_adapter'
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

        def get_addresses_info(addresses)
          @wallet_adapter.get_addresses_info(addresses)
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
      # @param color_id [Tapyrus::Color::ColorIdentifier] The color identifier associated with UTXO.
      #                    It will return only UTXOs with specified color_id. If color_id is nil, it will return all UTXOs.
      #                    If Tapyrus::Color::ColorIdentifier.default is specified, it will return uncolored UTXOs(i.e. TPC)
      # @param page [Integer] The page parameter is responsible for specifying the current page being viewed within the paginated results. default is 1.
      # @param per [Integer] The per parameter is used to determine the number of items to display per page. default is 25.
      def list_unspent_with_count(only_finalized = true, label = nil, color_id: nil, page: 1, per: 25)
        wallet_adapter.list_unspent_with_count(id, only_finalized, label, color_id: color_id, page: page, per: per)
      end

      # @param only_finalized [Boolean] The flag to get a UTXO with status only finalized
      # @param label [String] This label is used to filtered the UTXOs with labeled if a key or Utxo is labeled.
      #                    - If label is nil or :unlabeled, only unlabeled UTXOs will be returned.
      #                    - If label=:all, all UTXOs will be returned.
      # @param color_id [Tapyrus::Color::ColorIdentifier] The color identifier associated with UTXO.
      #                    It will return only UTXOs with specified color_id. If color_id is nil, it will return all UTXOs.
      #                    If Tapyrus::Color::ColorIdentifier.default is specified, it will return uncolored UTXOs(i.e. TPC)
      def list_unspent(only_finalized = true, label = :unlabeled, color_id: nil )
        label = :unlabeled unless label
        wallet_adapter.list_unspent(id, only_finalized, label, color_id: color_id)
      end

      def lock_unspent(utxo)
        wallet_adapter.lock_unspent(id, utxo)
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

      # Collect TPC UTXOs up to the specified amount.
      # @param [Integer] amount The amount of colored token to collect. If the amount is nil, return all TPC UTXOs
      # @param [String] label The label of UTXO to collect
      # @param [Boolean] only_finalized The flag to collect only finalized UTXO
      # @param [Boolean] shuffle The flag to shuffle UTXO before collecting
      # @param [Boolean] lock_utxos The flag to lock returning UTXOs to prevent to be used from other threads or processes
      # @param [Array<Hash] excludes The UTXO list to exclude the method result. Each hash must hub keys that are :txid and :vout
      # @return [Integer] The sum of return UTXOs
      # @return [Array<Hash>] An array of UTXO hash
      #
      # ## The UTXO structure
      #
      # - txid: [String] Transaction id
      # - vout: [Integer] Output index
      # - amount: [Integer] Amount of the UTXO as tapyrus unit
      # - finalized: [Boolean] Whether the UTXO is finalized
      # - script_pubkey: [String] ScriptPubkey of the UTXO
      def collect_uncolored_outputs(
        amount = nil,
        label = nil,
        only_finalized = true,
        shuffle = false,
        lock_utxos = false,
        excludes = []
      )
        collect_utxos(amount, label, Tapyrus::Color::ColorIdentifier.default, only_finalized, shuffle, lock_utxos, excludes) do |output|
          next yield(output) if block_given?

          true
        end
      end

      # Collect colored coin UTXOs up to the specified amount.
      # @param [Tapyrus::Color::ColorIdentifier] color_id The color identifier of colored token
      # @param [Integer] amount The amount of colored token to collect. If the amount is nil, return all UTXOs with color_id
      # @param [String] label The label of UTXO to collect
      # @param [Boolean] only_finalized The flag to collect only finalized UTXO
      # @param [Boolean] shuffle The flag to shuffle UTXO before collecting
      # @param [Boolean] lock_utxos The flag to lock returning UTXOs to prevent to be used from other threads or processes
      # @param [Array<Hash] excludes The UTXO list to exclude the method result. Each hash must hub keys that are :txid and :vout
      # @return [Integer] The sum of return UTXOs
      # @return [Array<Hash>] An array of UTXO hash
      #
      # ## The UTXO structure
      #
      # - txid: [String] Transaction id
      # - vout: [Integer] Output index
      # - amount: [Integer] Amount of the UTXO as tapyrus unit
      # - finalized: [Boolean] Whether the UTXO is finalized
      # - script_pubkey: [String] ScriptPubkey of the UTXO
      def collect_colored_outputs(
        color_id,
        amount = nil,
        label = nil,
        only_finalized = true,
        shuffle = false,
        lock_utxos = false,
        excludes = []
      )
        collect_utxos(amount, label, color_id, only_finalized, shuffle, lock_utxos, excludes) do |output|
          next yield(output) if block_given?

          true
        end
      rescue Glueby::Contract::Errors::InsufficientFunds
        raise Glueby::Contract::Errors::InsufficientTokens
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

      # Fill inputs in the tx up to target_amount of TPC from UTXOs in the wallet.
      # This method should be called before adding change output and script_sig in outputs.
      # FeeEstimator.dummy_tx returns fee amount to the TX that will be added one TPC input, a change TPC output and
      # script sigs in outputs.
      # @param [Tapyrus::Tx] tx The tx that will be filled the inputs
      # @param [Integer] target_amount The tapyrus amount the tx is expected to be added in this method
      # @param [Integer] current_amount The tapyrus amount the tx already has in its inputs
      # @param [Glueby::Contract::FeeEstimator] fee_estimator
      # @return [Tapyrus::Tx] tx The tx that is added inputs
      # @return [Integer] fee The final fee after the inputs are filled
      # @return [Integer] current_amount The final amount of the tx inputs
      # @return [Array<Hash>] provided_utxos The utxos that are added to the tx inputs
      def fill_uncolored_inputs(
        tx,
        target_amount: ,
        current_amount: 0,
        fee_estimator: Contract::FeeEstimator::Fixed.new,
        &block
      )
        fee = fee_estimator.fee(Contract::FeeEstimator.dummy_tx(tx, dummy_input_count: 0))
        provided_utxos = []

        while current_amount - fee < target_amount
          sum, utxos = collect_uncolored_outputs(
            fee + target_amount - current_amount,
            nil, false, true, true,
            provided_utxos,
            &block
          )

          utxos.each do |utxo|
            tx.inputs << Tapyrus::TxIn.new(out_point: Tapyrus::OutPoint.from_txid(utxo[:txid], utxo[:vout]))
            provided_utxos << utxo
          end
          current_amount += sum

          new_fee = fee_estimator.fee(Contract::FeeEstimator.dummy_tx(tx, dummy_input_count: 0))
          fee = new_fee
        end

        [tx, fee, current_amount, provided_utxos]
      end

      private

      def wallet_adapter
        self.class.wallet_adapter
      end

      def collect_utxos(
        amount,
        label,
        color_id,
        only_finalized = true,
        shuffle = true,
        lock_utxos = false,
        excludes = []
      )
        collect_all = amount.nil?

        raise Glueby::ArgumentError, 'amount must be positive' unless collect_all || amount.positive?
        utxos = list_unspent(only_finalized, label, color_id: color_id)
        utxos = utxos.shuffle if shuffle

        r = utxos.inject([0, []]) do |(sum, outputs), output|
          if excludes.is_a?(Array) &&
            !excludes.empty? &&
            excludes.find { |i| i[:txid] == output[:txid] && i[:vout] == output[:vout] }
            next [sum, outputs]
          end

          if block_given?
            next [sum, outputs] unless yield(output)
          end

          if lock_utxos
            next [sum, outputs] unless lock_unspent(output)
          end

          sum += output[:amount]
          outputs << output
          return [sum, outputs] unless collect_all || sum < amount

          [sum, outputs]
        end
        raise Glueby::Contract::Errors::InsufficientFunds unless collect_all

        r
      end
    end
  end
end
