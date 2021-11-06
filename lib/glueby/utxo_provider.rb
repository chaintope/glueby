module Glueby
  class UtxoProvider
    include Glueby::Contract::TxBuilder

    WALLET_ID = 'UTXO_PROVIDER_WALLET'
    DEFAULT_VALUE = 1_000

    def initialize(fee_estimator: Glueby::Contract::FixedFeeEstimator.new)
      @wallet = load_wallet
      @fee_estimator = fee_estimator
    end

    attr_reader :wallet, :fee_estimator

    # Provide a UTXO
    # @param [Tapyrus::Script] script_pubkey The script to be provided
    # @param [Integer] value The tpc amount to be provided
    # @return [Tapyrus::Tx] The tx that has a UTXO to be provided in its outputs
    # @return [Integer] The output index in the tx to indicate the place of a provided UTXO.
    # @raise [Glueby::Contract::Errors::InsufficientFunds] if provider does not have any utxo which has specified value.
    def get_utxo(script_pubkey, value = DEFAULT_VALUE)
      txb = Tapyrus::TxBuilder.new
      txb.pay(script_pubkey.addresses.first, value)

      fee = fee_estimator.fee(dummy_tx(txb.build))
      sum, outputs = wallet.collect_uncolored_outputs(fee + value)

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

    private

    # Create wallet for provider
    def load_wallet
      begin
        Glueby::Internal::Wallet.load(WALLET_ID)
      rescue Glueby::Internal::Wallet::Errors::WalletNotFound => _
        Glueby::Internal::Wallet.create(WALLET_ID)
      end
    end
  end
end