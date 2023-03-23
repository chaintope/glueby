module Glueby
  module Internal
    class TxBuilder
      extend Forwardable

      attr_reader :fee_estimator, :signer_wallet, :prev_txs

      def_delegators :@txb, :pay, :data

      def initialize
        @txb = Tapyrus::TxBuilder.new
        @utxos = []
        @prev_txs = []
      end

      # Set fee estimator
      # @param [Symbol|Glueby::Contract::FeeEstimator] fee_estimator :auto or :fixed
      def set_fee_estimator(fee_estimator)
        if fee_estimator.is_a?(Symbol)
          raise Glueby::ArgumentError, 'fee_estiamtor can be :fixed or :auto' unless valid_fee_estimator?(fee_estimator)
          @fee_estimator = get_fee_estimator(fee_estimator)
        else
          @fee_estimator = fee_estimator
        end
        self
      end

      # Set signer wallet. It is used to sign the transaction.
      # @param [Glueby::Wallet] wallet
      def set_signer_wallet(wallet)
        @signer_wallet = wallet
        self
      end

      # Add utxo to the transaction
      def add_utxo(utxo)
        @utxos << to_sign_tx_utxo_hash(utxo)
        @txb.add_utxo(to_tapyrusrb_utxo_hash(utxo))
        self
      end

      # Add an UTXO which is sent to the address
      # If the configuration is set to use UTXO provider, the UTXO is provided by the UTXO provider.
      # Otherwise, the UTXO is provided by the wallet. In this case, the address parameter is ignored.
      # @param [String] address The address that is the UTXO is sent to
      def add_utxo_to(address:, amount:, utxo_provider: nil)
        if Glueby.configuration.use_utxo_provider? || utxo_provider
          script_pubkey = Tapyrus::Script.parse_from_addr(address)
          tx, index = utxo_provider.get_utxo(script_pubkey, amount)

          @prev_txs << tx

          add_utxo({
            script_pubkey: tx.outputs[index].script_pubkey.to_hex,
            txid: tx.txid,
            vout: index,
            amount: tx.outputs[index].value
          })
        else
          raise NotImplementedError, 'Not implemented yet'
        end
        self
      end

      def build(dummy: false)
        return @txb.build if dummy

        @txb.fee(dummy_fee)
        fill_change_output

        tx = @txb.build
        signer_wallet.internal_wallet.sign_tx(tx, @utxos)
      end

      def dummy_fee
        fee_estimator.fee(Contract::FeeEstimator.dummy_tx(build(dummy: true)))
      end

      private

      def fill_change_output
        if Glueby.configuration.use_utxo_provider?
          @txb.change_address(UtxoProvider.instance.wallet.change_address)
        else
          @txb.change_address(@signer_wallet.internal_wallet.change_address)
        end
      end

      def get_fee_estimator(fee_estimator_name)
        Glueby::Contract::FeeEstimator.get_const("#{fee_estimator_name.capitalize}", false).new
      end

      def valid_fee_estimator?(fee_estimator)
        [:fixed, :auto].include?(fee_estimator)
      end

      # @param utxo
      # @option utxo [String] :txid The txid
      # @option utxo [Integer] :vout The index of the output in the tx
      # @option utxo [Integer] :amount The value of the output
      # @option utxo [String] :script_pubkey The hex string of the script pubkey
      def to_tapyrusrb_utxo_hash(utxo)
        {
          script_pubkey: Tapyrus::Script.parse_from_payload(utxo[:script_pubkey].htb),
          txid: utxo[:txid],
          index: utxo[:vout],
          value: utxo[:amount]
        }
      end

      # @param utxo
      # @option utxo [String] :txid The txid
      # @option utxo [Integer] :vout The index of the output in the tx
      # @option utxo [Integer] :amount The value of the output
      # @option utxo [String] :script_pubkey The hex string of the script pubkey
      def to_sign_tx_utxo_hash(utxo)
        {
          scriptPubKey: utxo[:script_pubkey],
          txid: utxo[:txid],
          vout: utxo[:vout],
          amount: utxo[:amount]
        }
      end
    end
  end
end

