module Glueby
  class UtxoProvider
    include Glueby::Contract::TxBuilder

    autoload :Tasks, 'glueby/utxo_provider/tasks'

    WALLET_ID = 'UTXO_PROVIDER_WALLET'
    DEFAULT_VALUE = 1_000
    DEFAULT_UTXO_POOL_SIZE = 20
    MAX_UTXO_POOL_SIZE = 2_000

    class << self
      attr_reader :config

      # @param [Hash] config
      # @option config [Integer] :default_value 
      # @option opts [Integer] :utxo_pool_size
      # @option opts [Glueby::Contract::FeeEstimator] :fee_estimator
      def configure(config)
        @config = config
      end
    end

    def initialize
      @wallet = load_wallet
      validate_config!
      @fee_estimator = (UtxoProvider.config && UtxoProvider.config[:fee_estimator]) || Glueby::Contract::FixedFeeEstimator.new
    end

    attr_reader :wallet, :fee_estimator

    # Provide a UTXO
    # @param [Tapyrus::Script] script_pubkey The script to be provided
    # @param [Integer] value The tpc amount to be provided
    # @return [Array<(Tapyrus::Tx, Integer)>]
    #  The tx that has a UTXO to be provided in its outputs.
    #  The output index in the tx to indicate the place of a provided UTXO.
    # @raise [Glueby::Contract::Errors::InsufficientFunds] if provider does not have any utxo which has specified value.
    def get_utxo(script_pubkey, value = DEFAULT_VALUE)
      txb = Tapyrus::TxBuilder.new
      txb.pay(script_pubkey.addresses.first, value)

      fee = fee_estimator.fee(dummy_tx(txb.build))
      # The outputs need to be shuffled so that no utxos are spent twice as possible.
      sum, outputs = collect_uncolored_outputs(@wallet, fee + value)

      outputs.each do |utxo|
        txb.add_utxo({
          script_pubkey: Tapyrus::Script.parse_from_payload(utxo[:script_pubkey].htb),
          txid: utxo[:txid],
          index: utxo[:vout],
          value: utxo[:amount]
        })
      end

      txb.fee(fee).change_address(@wallet.change_address)

      tx = txb.build
      signed_tx = @wallet.sign_tx(tx)
      [signed_tx, 0]
    end

    def default_value
      @default_value ||=
        (
          Glueby::AR::SystemInformation.utxo_provider_default_value ||
            (UtxoProvider.config && UtxoProvider.config[:default_value]) ||
            DEFAULT_VALUE
        )
    end

    def utxo_pool_size
      @utxo_pool_size ||=
        (
          Glueby::AR::SystemInformation.utxo_provider_pool_size ||
            (UtxoProvider.config && UtxoProvider.config[:utxo_pool_size]) ||
            DEFAULT_UTXO_POOL_SIZE
        )
    end

    def tpc_amount
      @wallet.balance(false)
    end

    def current_utxo_pool_size
      @wallet
        .list_unspent(false)
        .count { |o| !o[:color_id] && o[:amount] == default_value }
    end

    def address
      @address ||= @wallet.get_addresses.first || @wallet.receive_address
    end

    def value_to_fill_utxo_pool
      default_value * utxo_pool_size
    end

    private

    # Create wallet for provider
    def load_wallet
      begin
        Glueby::Internal::Wallet.load(WALLET_ID)
      rescue Glueby::Internal::Wallet::Errors::WalletNotFound => _
        Glueby::Internal::Wallet.create(WALLET_ID)
      end
    end

    def collect_uncolored_outputs(wallet, amount)
      utxos = wallet.list_unspent.select { |o| !o[:color_id] && o[:amount] == default_value }
      utxos.shuffle!

      utxos.inject([0, []]) do |sum, output|
        new_sum = sum[0] + output[:amount]
        new_outputs = sum[1] << output
        return [new_sum, new_outputs] if new_sum >= amount

        [new_sum, new_outputs]
      end
      raise Glueby::Contract::Errors::InsufficientFunds
    end

    def validate_config!
      if !utxo_pool_size.is_a?(Integer) || utxo_pool_size > MAX_UTXO_POOL_SIZE
        raise Glueby::Configuration::Errors::InvalidConfiguration, "utxo_pool_size(#{utxo_pool_size}) should not be greater than #{MAX_UTXO_POOL_SIZE}"
      end
    end
  end
end