module Glueby
  class FeeProvider
    include Singleton

    class NoUtxosInUtxoPool < StandardError; end

    WALLET_ID = 'FEE_PROVIDER_WALLET'
    DEFAULT_FIXED_FEE = 1000
    DEFAULT_UTXO_POOL_SIZE = 20

    attr_reader :fixed_fee, :utxo_pool_size, :wallet,

    class << self
      attr_reader :config

      # @param [Hash] config
      # @option config [Integer] :fixed_fee The amount of fee which FeeProvider would provide to the txs
      # @option opts [Integer] :utxo_pool_size The number of UTXOs in UTXO pool that is managed by FeeProvider
      def configure(config)
        @config = config
      end

      def provide(tx)
        instance.provide(tx)
      end
    end

    def initialize
      @wallet = begin
                  Internal::Wallet.load(WALLET_ID)
                rescue Internal::Wallet::Errors::WalletNotFound => _
                  Internal::Wallet.create(WALLET_ID)
                end

      @fixed_fee = (FeeProvider.config && FeeProvider.config[:fixed_fee]) || DEFAULT_FIXED_FEE
      @utxo_pool_size = (FeeProvider.config && FeeProvidr.config[:utxo_pool_size]) || DEFAULT_UTXO_POOL_SIZE
    end


    # Provide an input for fee to the tx.
    # @param [Tapyrus::Tx] tx - The tx that is provided fee as a input. It should be signed with ANYONECANPAY flag.
    # @return [Tapyrus::Tx]
    def provide(tx)
      utxo = utxo_for_fee
      out_point = Tapyrus::OutPoint.new(utxo[:txid].rhex, utxo[:vout])
      tx.inputs << Tapyrus::TxIn.new(out_point: out_point)

      wallet.sign_tx(tx)
    end

    private

    def utxo_for_fee
      utxo = wallet.list_unspent.find { |o| !o[:color_id] && o[:amount] == fixed_fee }
      raise NoUtxosInUtxoPool, 'No UTXOs in Fee Provider UTXO pool. UTXOs should be created with "glueby:fee_provider:manage_utxo_pool" rake task' unless utxo
      utxo
    end
  end
end