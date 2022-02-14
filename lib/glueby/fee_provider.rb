module Glueby
  class FeeProvider

    autoload :Tasks, 'glueby/fee_provider/tasks'

    class NoUtxosInUtxoPool < Error; end

    WALLET_ID = 'FEE_PROVIDER_WALLET'
    DEFAULT_FIXED_FEE = 1000
    DEFAULT_UTXO_POOL_SIZE = 20
    MAX_UTXO_POOL_SIZE = 2_000

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
        new.provide(tx)
      end
    end

    def initialize
      @wallet = begin
                  Internal::Wallet.load(WALLET_ID)
                rescue Internal::Wallet::Errors::WalletNotFound => _
                  Internal::Wallet.create(WALLET_ID)
                end

      validate_config!
      @fixed_fee = (FeeProvider.config && FeeProvider.config[:fixed_fee]) || DEFAULT_FIXED_FEE
      @utxo_pool_size = (FeeProvider.config && FeeProvider.config[:utxo_pool_size]) || DEFAULT_UTXO_POOL_SIZE
    end

    # Provide an input for fee to the tx.
    # @param [Tapyrus::Tx] tx - The tx that is provided fee as a input. It should be signed with ANYONECANPAY flag.
    # @return [Tapyrus::Tx]
    # @raise [Glueby::ArgumentError] If the signatures that the tx inputs has don't have ANYONECANPAY flag.
    # @raise [Glueby::FeeProvider::NoUtxosInUtxoPool] If there are no UTXOs for paying fee in FeeProvider's UTXO pool
    def provide(tx)
      tx.inputs.each do |txin|
        sig = get_signature(txin.script_sig)
        unless sig[-1].unpack1('C') & Tapyrus::SIGHASH_TYPE[:anyonecanpay] == Tapyrus::SIGHASH_TYPE[:anyonecanpay]
          raise ArgumentError, 'All the signatures that the tx inputs has should have ANYONECANPAY flag.'
        end
      end

      utxo = utxo_for_fee
      out_point = Tapyrus::OutPoint.new(utxo[:txid].rhex, utxo[:vout])
      tx.inputs << Tapyrus::TxIn.new(out_point: out_point)

      wallet.sign_tx(tx, for_fee_provider_input: true)
    end

    private

    def utxo_for_fee
      utxo = wallet.list_unspent.select { |o| !o[:color_id] && o[:amount] == fixed_fee }.sample
      raise NoUtxosInUtxoPool, 'No UTXOs in Fee Provider UTXO pool. UTXOs should be created with "glueby:fee_provider:manage_utxo_pool" rake task' unless utxo
      utxo
    end

    # Get Signature from P2PKH or CP2PKH script sig
    def get_signature(script_sig)
      script_sig.chunks.first.pushed_data
    end

    def validate_config!
      if FeeProvider.config
        utxo_pool_size = FeeProvider.config[:utxo_pool_size]
        if utxo_pool_size && (!utxo_pool_size.is_a?(Integer) || utxo_pool_size > MAX_UTXO_POOL_SIZE)
          raise Glueby::Configuration::Errors::InvalidConfiguration, "utxo_pool_size(#{utxo_pool_size}) should not be greater than #{MAX_UTXO_POOL_SIZE}"
        end
      end
    end
  end
end