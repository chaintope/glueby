module Glueby
  module Internal
    class TxBuilder < Tapyrus::TxBuilder
      attr_reader :fee_estimator, :signer_wallet, :prev_txs, :p2c_utxos, :use_unfinalized_utxo, :use_auto_fee

      # @param [Glueby::Internal::Wallet] signer_wallet The wallet that is used to sign the transaction.
      # @param [Symbol|Glueby::Contract::FeeEstimator] fee_estimator :auto or :fixed
      # @param [Boolean] use_auto_fee If it's true, inputs are automatically added to fulfill the fee.
      #                               The TPC for the fee is supply from the signer_wallet or UtxoProvider
      #                               and it is selected automatically from configuration. If using the UTXO
      #                               Provider is enabled, it uses UTXO Provider. If it's false, an user of
      #                               TxBuilder need to add UTXOs to pay the fee manually. This behavior
      #                               works independently of the FeeProvider.
      # @param [Boolean] use_unfinalized_utxo If it's true, The TxBuilder use unfinalized UTXO that is not
      #                                       included in the block in its inputs.
      def initialize(
        signer_wallet:,
        fee_estimator: :auto,
        use_auto_fee: false,
        use_unfinalized_utxo: false
      )
        @signer_wallet = signer_wallet
        set_fee_estimator(fee_estimator)
        @use_auto_fee = use_auto_fee
        @use_unfinalized_utxo = use_unfinalized_utxo
        @p2c_utxos = []
        @prev_txs = []
        super()
      end

      # Issue reissuable token to the split outputs
      # @param [Tapyrus::Script] script_pubkey The color id is generate from this script pubkey
      # @param [String] address The address that is the token is sent to
      # @param [Integer] value The issue amount of the token
      # @param [Integer] split The number of the split outputs
      def reissuable_split(script_pubkey, address, value, split)
        if value < split
          split = value
          split_value = 1
        else
          split_value = (value / split).to_i
        end
        (split - 1).times { reissuable(script_pubkey, address, split_value) }
        reissuable(script_pubkey, address, value - split_value * (split - 1))
        self
      end

      def non_reissuable_split(out_point, address, value, split)
        if value < split
          split = value
          split_value = 1
        else
          split_value = (value / split).to_i
        end
        (split - 1).times { non_reissuable(out_point, address, split_value) }
        non_reissuable(out_point, address, value - split_value * (split - 1))
        self
      end

      # Add utxo to the transaction
      def add_utxo(utxo)
        super(to_tapyrusrb_utxo_hash(utxo))
        self
      end

      # Add an UTXO which is sent to the address
      # If the configuration is set to use UTXO provider, the UTXO is provided by the UTXO provider.
      # Otherwise, the UTXO is provided by the wallet. In this case, the address parameter is ignored.
      # This method creates and broadcasts a transaction that sends the amount to the address and add the UTXO
      # to the transaction.
      # @param [String] address The address that is the UTXO is sent to
      # @param [Integer] amount The amount of the UTXO
      # @param [Glueby::Internal::UtxoProvider] utxo_provider The UTXO provider
      # @param [Boolean] only_finalized If true, the UTXO is provided from the finalized UTXO set. It is ignored if the configuration is set to use UTXO provider.
      # @param [Glueby::Contract::FeeEstimator] fee_estimator It estimate fee for prev tx. It is ignored if the configuration is set to use UTXO provider.
      def add_utxo_to(
        address:,
        amount:,
        utxo_provider: nil,
        only_finalized: use_only_finalized_utxo,
        fee_estimator: nil
      )
        tx, index = nil

        if Glueby.configuration.use_utxo_provider? || utxo_provider
          utxo_provider ||= UtxoProvider.instance
          script_pubkey = Tapyrus::Script.parse_from_addr(address)
          tx, index = utxo_provider.get_utxo(script_pubkey, amount)
        else
          fee_estimator ||= @fee_estimator
          txb = Tapyrus::TxBuilder.new
          fee = fee_estimator.fee(Contract::FeeEstimator.dummy_tx(txb.build))
          _sum, utxos = signer_wallet
                         .collect_uncolored_outputs(fee + amount, nil, only_finalized)
          utxos.each { |utxo| txb.add_utxo(to_tapyrusrb_utxo_hash(utxo)) }
          tx = txb.pay(address, amount)
                  .change_address(signer_wallet.change_address)
                  .fee(fee)
                  .build
          signer_wallet.sign_tx(tx)
          index = 0
        end

        ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
          # Here needs to use the return tx from Internal::Wallet#broadcast because the txid
          # is changed if you enable FeeProvider.
          tx = signer_wallet.broadcast(tx)
        end

        @prev_txs << tx

        add_utxo({
          script_pubkey: tx.outputs[index].script_pubkey.to_hex,
          txid: tx.txid,
          vout: index,
          amount: tx.outputs[index].value
        })
        self
      end

      # Add an UTXO which is sent to the pay-to-contract address
      # @param [String] metadata The metadata of the pay-to-contract address
      # @param [Integer] amount The amount of the UTXO
      # @param [String] p2c_address The pay-to-contract address. You can use this parameter if you want to create an
      #                             UTXO to before created address. It must be use with payment_base parameter.
      # @param [String] payment_base The payment base of the pay-to-contract address. It should be compressed public
      #                              key format. It must be use with p2c_address parameter.
      # @param [Boolean] only_finalized If true, the UTXO is provided from the finalized UTXO set. It is ignored if the configuration is set to use UTXO provider.
      # @param [Glueby::Contract::FeeEstimator] fee_estimator It estimate fee for prev tx. It is ignored if the configuration is set to use UTXO provider.
      def add_p2c_utxo_to(
        metadata:,
        amount:,
        p2c_address: nil,
        payment_base: nil,
        only_finalized: use_only_finalized_utxo,
        fee_estimator: nil
      )
        if p2c_address.nil? || payment_base.nil?
          p2c_address, payment_base = signer_wallet
                                        .create_pay_to_contract_address(metadata)
        end

        add_utxo_to(
          address: p2c_address,
          amount: amount,
          only_finalized: only_finalized,
          fee_estimator: fee_estimator
        )
        @p2c_utxos << to_p2c_sign_tx_utxo_hash(@utxos.last)
                        .merge({
                          p2c_address: p2c_address,
                          payment_base: payment_base,
                          metadata: metadata
                        })
        self
      end

      alias_method :original_build, :build
      def build
        tx = if @use_auto_fee && Glueby.configuration.use_utxo_provider?
               auto_fee_with_utxo_provider(super)
             elsif @use_auto_fee
               fee(dummy_fee)
               auto_fee_with_signer_wallet
               fill_change_output
               super
             else
               fee(dummy_fee)
               fill_change_output
               super
             end

        sign(tx)
      end

      def dummy_fee
        fee_estimator.fee(Contract::FeeEstimator.dummy_tx(original_build))
      end

      private

      def sign(tx)
        utxos = @utxos.map { |u| to_sign_tx_utxo_hash(u) }
        tx = signer_wallet.sign_tx(tx, utxos)

        @p2c_utxos.each do |utxo|
          tx = signer_wallet
                 .sign_to_pay_to_contract_address(tx, utxo, utxo[:payment_base], utxo[:metadata])
        end
        tx
      end

      def fill_change_output
        if Glueby.configuration.use_utxo_provider?
          change_address(UtxoProvider.instance.wallet.change_address)
        else
          change_address(@signer_wallet.change_address)
        end
      end

      def get_fee_estimator(fee_estimator_name)
        Glueby::Contract::FeeEstimator.get_const("#{fee_estimator_name.capitalize}", false).new
      end

      def valid_fee_estimator?(fee_estimator)
        [:fixed, :auto].include?(fee_estimator)
      end

      def auto_fee_with_utxo_provider(tx)
        utxo_provider = UtxoProvider.instance
        tx, fee, tpc_amount, provided_utxos = utxo_provider.fill_inputs(
          tx,
          target_amount: 0,
          current_amount: @incomings[Tapyrus::Color::ColorIdentifier.default],
          fee_estimator: fee_estimator
        )

        if tpc_amount - fee > 0
          change_script = Tapyrus::Script.parse_from_addr(utxo_provider.wallet.change_address)
          tx.outputs << Tapyrus::TxOut.new(value: tpc_amount - fee, script_pubkey: change_script)
        end

        utxo_provider.wallet.sign_tx(tx, provided_utxos)
      end

      def auto_fee_with_signer_wallet
        # TODO: Support the case of increasing fee by adding multiple inputs
        _, outputs = signer_wallet
                       .collect_uncolored_outputs(estimated_fee, nil, use_only_finalized_utxo)
        outputs.each { |o| add_utxo(o) }
      end

      def use_only_finalized_utxo
        !use_unfinalized_utxo
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

      # The UTXO format that is used in Tapyrus::TxBuilder
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

      # The UTXO format that is used in AbstractWalletAdapter#sign_tx
      # @param utxo The return value of #to_tapyrusrb_utxo_hash
      # @option utxo [String] :txid The txid
      # @option utxo [Integer] :index The index of the output in the tx
      # @option utxo [Integer] :amount The value of the output
      # @option utxo [String] :script_pubkey The hex string of the script pubkey
      def to_sign_tx_utxo_hash(utxo)
        {
          scriptPubKey: utxo[:script_pubkey].to_hex,
          txid: utxo[:txid],
          vout: utxo[:index],
          amount: utxo[:amount]
        }
      end

      # The UTXO format that is used in AbstractWalletAdapter#sign_to_pay_to_contract_address
      # @param utxo The return value of #to_tapyrusrb_utxo_hash
      # @option utxo [String] :txid The txid
      # @option utxo [Integer] :index The index of the output in the tx
      # @option utxo [Integer] :amount The value of the output
      # @option utxo [String] :script_pubkey The hex string of the script pubkey
      def to_p2c_sign_tx_utxo_hash(utxo)
        {
          script_pubkey: utxo[:script_pubkey].to_hex,
          txid: utxo[:txid],
          vout: utxo[:index],
          amount: utxo[:amount]
        }
      end
    end
  end
end
