module Glueby
  module Internal
    class ContractBuilder < Tapyrus::TxBuilder
      attr_reader :fee_estimator, :sender_wallet, :prev_txs, :p2c_utxos, :use_unfinalized_utxo, :use_auto_fulfill_inputs

      # @param [Glueby::Internal::Wallet] sender_wallet The wallet that is an user's wallet who send the transaction
      #                                                 to a blockchain.
      # @param [Symbol|Glueby::Contract::FeeEstimator] fee_estimator :auto or :fixed
      # @param [Boolean] use_auto_fulfill_inputs
      #   If it's true, inputs are automatically added up to fulfill the TPC and tokens requirement that is added by
      #   #pay and #burn. The option also support to fill adding TPC inputs for paying fee.
      #   If Glueby.configuration.use_utxo_provider? is true, All the TPC inputs are added from the UtxoProvider's
      #   wallet. It it's false, all the TPC inputs are from sender_wallet.
      #   If Glueby.configuration.fee_provider_bears? is true, it won't add TPC amount for fee.
      # @param [Boolean] use_unfinalized_utxo If it's true, The ContractBuilder use unfinalized UTXO that is not
      #                                       included in the block in its inputs.
      # @raise [Glueby::ArgumentError] If the fee_estimator is not :auto or :fixed
      def initialize(
        sender_wallet:,
        fee_estimator: :auto,
        use_auto_fulfill_inputs: false,
        use_unfinalized_utxo: false
      )
        @sender_wallet = sender_wallet
        set_fee_estimator(fee_estimator)
        @use_auto_fulfill_inputs = use_auto_fulfill_inputs
        @use_unfinalized_utxo = use_unfinalized_utxo
        @p2c_utxos = []
        @prev_txs = []
        @change_script_pubkeys = {}
        @burn_contract = false
        @issues = Hash.new(0)
        super()
      end

      # Issue reissuable token
      # @param script_pubkey [Tapyrus::Script] the script pubkey in the issue input.
      # @param address [String] p2pkh or p2sh address.
      # @param value [Integer] issued amount.
      def reissuable(script_pubkey, address, value)
        color_id = Tapyrus::Color::ColorIdentifier.reissuable(script_pubkey)
        @issues[color_id] += value
        super
      end

      # Issue reissuable token to the split outputs
      # @param [Tapyrus::Script] script_pubkey The color id is generate from this script pubkey
      # @param [String] address The address that is the token is sent to
      # @param [Integer] value The issue amount of the token
      # @param [Integer] split The number of the split outputs
      def reissuable_split(script_pubkey, address, value, split)
        split_value(value, split) do |value|
          reissuable(script_pubkey, address, value)
        end
      end

      # Issue non reissuable token
      # @param out_point [Tapyrus::OutPoint] the out point at issue input.
      # @param address [String] p2pkh or p2sh address.
      # @param value [Integer] issued amount.
      def non_reissuable(out_point, address, value)
        color_id = Tapyrus::Color::ColorIdentifier.non_reissuable(out_point)
        @issues[color_id] += value
        super
      end

      # Issue non-reissuable token to the split outputs
      # @param [Tapyrus::OutPoint] out_point The outpoint of the reissuable token
      # @param [String] address The address that is the token is sent to
      # @param [Integer] value The issue amount of the token
      # @param [Integer] split The number of the split outputs
      def non_reissuable_split(out_point, address, value, split)
        split_value(value, split) do |value|
          non_reissuable(out_point, address, value)
        end
      end

      # Issue NFT
      # @param out_point [Tapyrus::OutPoint] the out point at issue input.
      # @param address [String] p2pkh or p2sh address.
      # @raise [Glueby::ArgumentError] If the NFT is already issued in this contract builder.
      def nft(out_point, address)
        color_id = Tapyrus::Color::ColorIdentifier.nft(out_point)
        raise Glueby::ArgumentError, 'NFT is already issued.' if @issues[color_id] == 1
        @issues[color_id] = 1
        super
      end

      # Burn token
      # @param [Integer] value The burn amount of the token
      # @param [Tapyrus::Color::ColorIdentifier] color_id The color id of the token
      # @raise [Glueby::ArgumentError] If the color_id is default color id
      def burn(value, color_id)
        raise Glueby::ArgumentError, 'Burn TPC is not supported.' if color_id.default?

        @burn_contract = true
        @outgoings[color_id] ||= 0
        @outgoings[color_id] += value
        self
      end

      # Add utxo to the transaction
      # @param [Hash] utxo The utxo to add
      # @option utxo [String] :txid The txid
      # @option utxo [Integer] :vout The index of the output in the tx
      # @option utxo [Integer] :amount The value of the output
      # @option utxo [String] :script_pubkey The hex string of the script pubkey
      # @option utxo [String] :color_id The color id hex string of the output
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
      def add_utxo_to!(
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
          _sum, utxos = sender_wallet
                         .collect_uncolored_outputs(fee + amount, nil, only_finalized)
          utxos.each { |utxo| txb.add_utxo(to_tapyrusrb_utxo_hash(utxo)) }
          tx = txb.pay(address, amount)
                  .change_address(sender_wallet.change_address)
                  .fee(fee)
                  .build
          sender_wallet.sign_tx(tx)
          index = 0
        end

        ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
          # Here needs to use the return tx from Internal::Wallet#broadcast because the txid
          # is changed if you enable FeeProvider.
          tx = sender_wallet.broadcast(tx)
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

      # Add an UTXO which is sent to the pay-to-contract address which is generated from the metadata
      # @param [String] metadata The metadata of the pay-to-contract address
      # @param [Integer] amount The amount of the UTXO
      # @param [String] p2c_address The pay-to-contract address. You can use this parameter if you want to create an
      #                             UTXO to before created address. It must be use with payment_base parameter.
      # @param [String] payment_base The payment base of the pay-to-contract address. It should be compressed public
      #                              key format. It must be use with p2c_address parameter.
      # @param [Boolean] only_finalized If true, the UTXO is provided from the finalized UTXO set. It is ignored if the configuration is set to use UTXO provider.
      # @param [Glueby::Contract::FeeEstimator] fee_estimator It estimate fee for prev tx. It is ignored if the configuration is set to use UTXO provider.
      def add_p2c_utxo_to!(
        metadata:,
        amount:,
        p2c_address: nil,
        payment_base: nil,
        only_finalized: use_only_finalized_utxo,
        fee_estimator: nil
      )
        if p2c_address.nil? || payment_base.nil?
          p2c_address, payment_base = sender_wallet
                                        .create_pay_to_contract_address(metadata)
        end

        add_utxo_to!(
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

      alias :original_build :build
      def build
        auto_fulfill_inputs_utxos_for_color if use_auto_fulfill_inputs

        tx = Tapyrus::Tx.new
        set_tpc_change_address
        expand_input(tx)
        @outputs.each { |output| tx.outputs << output }
        add_change_for_colored_coin(tx)


        change, provided_utxos = auto_fulfill_inputs_utxos_for_tpc(tx) if use_auto_fulfill_inputs
        add_change_for_tpc(tx, change)

        add_dummy_output(tx)
        sign(tx, provided_utxos)
      end

      def change_address(address, color_id = Tapyrus::Color::ColorIdentifier.default)
        if color_id.default?
          super(address)
        else
          script_pubkey = Tapyrus::Script.parse_from_addr(address)
          raise ArgumentError, 'invalid address' if !script_pubkey.p2pkh? && !script_pubkey.p2sh?
          @change_script_pubkeys[color_id] = script_pubkey.add_color(color_id)
        end
        self
      end

      private :fee

      def dummy_fee
        fee_estimator.fee(Contract::FeeEstimator.dummy_tx(original_build))
      end

      private

      def estimated_fee
        @fee ||= estimate_fee
      end

      def estimate_fee
        tx = Tapyrus::Tx.new
        expand_input(tx)
        @outputs.each { |output| tx.outputs << output }
        add_change_for_colored_coin(tx)
        fee_estimator.fee(Contract::FeeEstimator.dummy_tx(tx))
      end

      def sign(tx, extra_utxos)
        utxos = @utxos.map { |u| to_sign_tx_utxo_hash(u) } + (extra_utxos || [])

        # Sign inputs from sender_wallet
        tx = sender_wallet.sign_tx(tx, utxos)

        # Sign inputs which is pay to contract output
        @p2c_utxos.each do |utxo|
          tx = sender_wallet
                 .sign_to_pay_to_contract_address(tx, utxo, utxo[:payment_base], utxo[:metadata])
        end

        # Sign inputs from UtxoProvider
        Glueby::UtxoProvider.instance.wallet.sign_tx(tx, utxos) if Glueby.configuration.use_utxo_provider?

        tx
      end

      def set_tpc_change_address
        if Glueby.configuration.use_utxo_provider?
          change_address(UtxoProvider.instance.wallet.change_address)
        else
          change_address(@sender_wallet.change_address)
        end
      end

      def add_change_for_colored_coin(tx)
        @incomings.each do |color_id, in_amount|
          next if color_id.default?

          out_amount = @outgoings[color_id] || 0
          change = in_amount - out_amount
          next if change <= 0

          unless @change_script_pubkeys[color_id]
            raise Glueby::ArgumentError, "The change address for color_id #{color_id.to_hex} must be set."
          end
          tx.outputs << Tapyrus::TxOut.new(script_pubkey: @change_script_pubkeys[color_id], value: change)
        end
        tx
      end

      def add_change_for_tpc(tx, change = nil)
        raise Glueby::ArgumentError, "The change address for TPC must be set." unless @change_script_pubkey
        change ||= begin
                     in_amount = @incomings[Tapyrus::Color::ColorIdentifier.default] || 0
                     out_amount = @outgoings[Tapyrus::Color::ColorIdentifier.default] || 0

                     in_amount - out_amount - estimated_fee
                   end

        raise Contract::Errors::InsufficientFunds if change < 0

        change_output = Tapyrus::TxOut.new(script_pubkey: @change_script_pubkey, value: change)
        return tx if change_output.dust?

        tx.outputs << change_output

        tx
      end

      # @return [Integer] The TPC change amount
      # @return [Array<Hash>] The provided UTXOs
      def auto_fulfill_inputs_utxos_for_tpc(tx)
        target_amount = @outgoings[Tapyrus::Color::ColorIdentifier.default] || 0

        provider = if Glueby.configuration.use_utxo_provider?
                     UtxoProvider.instance
                   else
                     sender_wallet
                   end

        _tx, fee, tpc_amount, provided_utxos = provider.fill_uncolored_inputs(
          tx,
          target_amount: target_amount,
          current_amount: @incomings[Tapyrus::Color::ColorIdentifier.default] || 0,
          fee_estimator: fee_estimator
        )

        change = tpc_amount - target_amount - fee
        [change, provided_utxos]
      end

      def auto_fulfill_inputs_utxos_for_color
        # fulfill colored inputs
        @outgoings.each do |color_id, outgoing_amount|
          next if color_id.default?

          target_amount = outgoing_amount - (@incomings[color_id] || 0) - @issues[color_id]
          next if target_amount <= 0

          @sender_wallet.collect_colored_outputs(
            color_id,
            target_amount,
            nil,
            use_only_finalized_utxo,
            true
          )[1]
            .each { |utxo| add_utxo(utxo) }
        end

      end

      def get_fee_estimator(fee_estimator_name)
        Glueby::Contract::FeeEstimator.get_const("#{fee_estimator_name.capitalize}", false).new
      end

      def valid_fee_estimator?(fee_estimator)
        [:fixed, :auto].include?(fee_estimator)
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

      # Split the value into the number of split. The last value is added the remainder of the division.
      # It call the block with the value of each split.
      def split_value(value, split)
        if value < split
          split = value
          split_value = 1
        else
          split_value = (value / split).to_i
        end
        (split - 1).times { yield(split_value) }
        yield(value - split_value * (split - 1))
        self
      end

      # If the tx has no output due to the contract creating a burn token, a dummy output should be added to make
      # the transaction valid.
      def add_dummy_output(tx)
        if @burn_contract && tx.outputs.size == 0

          tx.outputs << Tapyrus::TxOut.new(
            value: 0,
            script_pubkey: Tapyrus::Script.new << Tapyrus::Opcodes::OP_RETURN
          )
        end
      end

      # The UTXO format that is used in Tapyrus::TxBuilder
      # @param utxo
      # @option utxo [String] :txid The txid
      # @option utxo [Integer] :vout The index of the output in the tx
      # @option utxo [Integer] :amount The value of the output
      # @option utxo [String] :script_pubkey The hex string of the script pubkey
      # @option utxo [String] :color_id The hex string of the color id
      def to_tapyrusrb_utxo_hash(utxo)
        color_id = if utxo[:color_id]
                     Tapyrus::Color::ColorIdentifier.parse_from_payload(utxo[:color_id].htb)
                   else
                     Tapyrus::Color::ColorIdentifier.default
                   end
        {
          script_pubkey: Tapyrus::Script.parse_from_payload(utxo[:script_pubkey].htb),
          txid: utxo[:txid],
          index: utxo[:vout],
          value: utxo[:amount],
          color_id: color_id
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
          amount: utxo[:value]
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
          amount: utxo[:value]
        }
      end
    end
  end
end

