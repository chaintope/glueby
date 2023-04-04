module Glueby
  class UtxoProvider
    include Singleton

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
      # @option opts [Glueby::Contract::FeeEstimator] :fee_estimator_for_manage It uses this estimator in glueby:utxo_provider:manage_utxo_pool rake task.
      #                                                                         If it is nil, it uses same as :fee_estimator instead.
      def configure(config)
        @config = config
      end
    end

    def initialize
      @wallet = load_wallet
      validate_config!
      @fee_estimator = (UtxoProvider.config && UtxoProvider.config[:fee_estimator]) || Glueby::Contract::FeeEstimator::Fixed.new
      @fee_estimator_for_manage = UtxoProvider.config && UtxoProvider.config[:fee_estimator_for_manage] || @fee_estimator
    end

    attr_reader :wallet, :fee_estimator, :fee_estimator_for_manage, :address

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

      fee = fee_estimator.fee(Contract::FeeEstimator.dummy_tx(txb.build))
      # The outputs need to be shuffled so that no utxos are spent twice as possible.
      sum, outputs = collect_uncolored_outputs(wallet, fee + value)

      outputs.each do |utxo|
        txb.add_utxo({
          script_pubkey: Tapyrus::Script.parse_from_payload(utxo[:script_pubkey].htb),
          txid: utxo[:txid],
          index: utxo[:vout],
          value: utxo[:amount]
        })
      end

      txb.fee(fee).change_address(wallet.change_address)

      tx = txb.build
      signed_tx = wallet.sign_tx(tx)
      [signed_tx, 0]
    end

    # Fill inputs in the tx up to target_amount of TPC from UTXO pool
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
    def fill_inputs(tx, target_amount: , current_amount: 0, fee_estimator: Contract::FeeEstimator::Fixed.new)
      fee = fee_estimator.fee(Contract::FeeEstimator.dummy_tx(tx, dummy_input_count: 0))
      provided_utxos = []

      # If the change output value is less than DUST_LIMIT, tapyrus core returns "dust" error while broadcasting.
      target_amount += DUST_LIMIT if target_amount < DUST_LIMIT

      while current_amount - fee < target_amount
        sum, utxos = collect_uncolored_outputs(wallet, fee + target_amount - current_amount, provided_utxos)

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
      wallet.balance(false)
    end

    def current_utxo_pool_size
      wallet
        .list_unspent(false)
        .count { |o| !o[:color_id] && o[:amount] == default_value }
    end

    def address
      @address ||= wallet.get_addresses.first || wallet.receive_address
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

    # Collects and returns TPC UTXOs.
    # @param [Glueby::Internal::Wallet] wallet The wallet that funds the caller
    # @param [Integer] amount The target amount which to be collected
    # @param [Array<Hash>] excludes The exclusion UTXO list. It excludes this UTXOs from the targets that will be collected TPC UTXOs.
    # @return [Integer] sum The sum amount of the funds
    # @return [Array<Hash>] outputs The UTXO set of the funds
    def collect_uncolored_outputs(wallet, amount, excludes = [])
      utxos = wallet.list_unspent.select do |o|
        !o[:color_id] &&
          o[:amount] == default_value &&
          !excludes.find { |i| i[:txid] == o[:txid] && i[:vout] == o[:vout] }
      end
      utxos.shuffle!
      
      utxos.inject([0, []]) do |(sum, outputs), output|
        if wallet.lock_unspent(output)
          sum += output[:amount]
          outputs << output
          return [sum, outputs] if sum >= amount
        end
        [sum, outputs]
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