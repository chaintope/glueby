# frozen_string_literal: true

module Glueby
  module Contract
    # @deprecated Use Glueby::Internal::ContractBuilder instead. This class will be removed in the future.
    module TxBuilder
      def receive_address(wallet:)
        wallet.receive_address
      end

      # Create new public key, and new transaction that sends TPC to it
      def create_funding_tx(wallet:, script: nil, fee_estimator: FeeEstimator::Fixed.new, only_finalized: true)
        if Glueby.configuration.use_utxo_provider?
          utxo_provider = UtxoProvider.new
          script_pubkey = script ? script : Tapyrus::Script.parse_from_addr(wallet.internal_wallet.receive_address)
          funding_tx, _index = utxo_provider.get_utxo(script_pubkey, funding_tx_amount)
          utxo_provider.wallet.sign_tx(funding_tx)
        else
          txb = Tapyrus::TxBuilder.new
          fee = fee_estimator.fee(FeeEstimator.dummy_tx(txb.build))
          amount = fee + funding_tx_amount
          sum, outputs = wallet.internal_wallet.collect_uncolored_outputs(amount, nil, only_finalized)
          outputs.each do |utxo|
            txb.add_utxo({
              script_pubkey: Tapyrus::Script.parse_from_payload(utxo[:script_pubkey].htb),
              txid: utxo[:txid],
              index: utxo[:vout],
              value: utxo[:amount]
            })
          end
  
          receiver_address = script ? script.addresses.first : wallet.internal_wallet.receive_address
          tx = txb.pay(receiver_address, funding_tx_amount)
            .change_address(wallet.internal_wallet.change_address)
            .fee(fee)
            .build
          wallet.internal_wallet.sign_tx(tx)
        end
      end

      def create_issue_tx_for_reissuable_token(funding_tx:, issuer:, amount:, split: 1, fee_estimator: FeeEstimator::Fixed.new)
        tx = Tapyrus::Tx.new

        out_point = Tapyrus::OutPoint.from_txid(funding_tx.txid, 0)
        tx.inputs << Tapyrus::TxIn.new(out_point: out_point)
        output = funding_tx.outputs.first

        receiver_script = Tapyrus::Script.parse_from_addr(issuer.internal_wallet.receive_address)
        funding_script = Tapyrus::Script.parse_from_payload(output.script_pubkey.to_payload)
        color_id = Tapyrus::Color::ColorIdentifier.reissuable(funding_script)
        receiver_colored_script = receiver_script.add_color(color_id)

        add_split_output(tx, amount, split, receiver_colored_script)

        fee = fee_estimator.fee(FeeEstimator.dummy_tx(tx))

        prev_txs = [{
          txid: funding_tx.txid,
          vout: 0,
          scriptPubKey: output.script_pubkey.to_hex,
          amount: output.value
        }]

        utxo_provider = nil

        if Glueby.configuration.use_utxo_provider?
          utxo_provider = UtxoProvider.new
          tx, fee, input_amount, provided_utxos = utxo_provider.fill_inputs(
            tx,
            target_amount: 0,
            current_amount: output.value,
            fee_estimator: fee_estimator
          )
          prev_txs.concat(provided_utxos)
        else
          # TODO: Support the case of providing UTXOs from sender's wallet.
          input_amount = output.value
        end

        fill_change_tpc(tx, issuer, input_amount - fee)

        utxo_provider.wallet.sign_tx(tx, prev_txs) if Glueby.configuration.use_utxo_provider?
        issuer.internal_wallet.sign_tx(tx, prev_txs)
      end

      def create_issue_tx_for_non_reissuable_token(funding_tx: nil, issuer:, amount:, split: 1, fee_estimator: FeeEstimator::Fixed.new, only_finalized: true)
        create_issue_tx_from_out_point(funding_tx: funding_tx, token_type: Tapyrus::Color::TokenTypes::NON_REISSUABLE, issuer: issuer, amount: amount, split: split, fee_estimator: fee_estimator, only_finalized: only_finalized)
      end

      def create_issue_tx_for_nft_token(funding_tx: nil, issuer:, fee_estimator: FeeEstimator::Fixed.new, only_finalized: true)
        create_issue_tx_from_out_point(funding_tx: funding_tx, token_type: Tapyrus::Color::TokenTypes::NFT, issuer: issuer, amount: 1, fee_estimator: fee_estimator, only_finalized: only_finalized)
      end

      def create_issue_tx_from_out_point(funding_tx: nil, token_type:, issuer:, amount:, split: 1, fee_estimator: FeeEstimator::Fixed.new, only_finalized: true)
        tx = Tapyrus::Tx.new

        fee = fee_estimator.fee(dummy_issue_tx_from_out_point)
        sum = if funding_tx
          out_point = Tapyrus::OutPoint.from_txid(funding_tx.txid, 0)
          tx.inputs << Tapyrus::TxIn.new(out_point: out_point)
          funding_tx.outputs.first.value
        else
          sum, outputs = issuer.internal_wallet.collect_uncolored_outputs(fee, nil, only_finalized)
          fill_input(tx, outputs)
          sum
        end
        out_point = tx.inputs.first.out_point
        color_id = case token_type
        when Tapyrus::Color::TokenTypes::NON_REISSUABLE
          Tapyrus::Color::ColorIdentifier.non_reissuable(out_point)
        when Tapyrus::Color::TokenTypes::NFT
          Tapyrus::Color::ColorIdentifier.nft(out_point)
        else
          raise Glueby::Contract::Errors::UnsupportedTokenType  
        end

        receiver_script = Tapyrus::Script.parse_from_addr(issuer.internal_wallet.receive_address)
        receiver_colored_script = receiver_script.add_color(color_id)
        add_split_output(tx, amount, split, receiver_colored_script)

        prev_txs = if funding_tx
                     output = funding_tx.outputs.first
                     [{
                       txid: funding_tx.txid,
                       vout: 0,
                       scriptPubKey: output.script_pubkey.to_hex,
                       amount: output.value
                     }]
                   else
                     []
                   end

        utxo_provider = nil

        if Glueby.configuration.use_utxo_provider?
          utxo_provider = UtxoProvider.new
          tx, fee, sum, provided_utxos = utxo_provider.fill_inputs(
            tx,
            target_amount: 0,
            current_amount: sum,
            fee_estimator: fee_estimator
          )
          prev_txs.concat(provided_utxos)
        end

        fill_change_tpc(tx, issuer, sum - fee)

        utxo_provider.wallet.sign_tx(tx, prev_txs) if Glueby.configuration.use_utxo_provider?
        issuer.internal_wallet.sign_tx(tx, prev_txs)
      end

      def create_reissue_tx(funding_tx:, issuer:, amount:, color_id:, split: 1, fee_estimator: FeeEstimator::Fixed.new)
        tx = Tapyrus::Tx.new

        out_point = Tapyrus::OutPoint.from_txid(funding_tx.txid, 0)
        tx.inputs << Tapyrus::TxIn.new(out_point: out_point)
        output = funding_tx.outputs.first

        receiver_script = Tapyrus::Script.parse_from_addr(issuer.internal_wallet.receive_address)
        receiver_colored_script = receiver_script.add_color(color_id)
        add_split_output(tx, amount, split, receiver_colored_script)

        fee = fee_estimator.fee(FeeEstimator.dummy_tx(tx))

        prev_txs = [{
          txid: funding_tx.txid,
          vout: 0,
          scriptPubKey: output.script_pubkey.to_hex,
          amount: output.value
        }]

        utxo_provider = nil

        if Glueby.configuration.use_utxo_provider?
          utxo_provider = UtxoProvider.new
          tx, fee, input_amount, provided_utxos = utxo_provider.fill_inputs(
            tx,
            target_amount: 0,
            current_amount: output.value,
            fee_estimator: fee_estimator
          )
          prev_txs.concat(provided_utxos)
        else
          # TODO: Support the case of providing UTXOs from sender's wallet.
          input_amount = output.value
        end

        fill_change_tpc(tx, issuer, input_amount - fee)

        utxo_provider.wallet.sign_tx(tx, prev_txs) if Glueby.configuration.use_utxo_provider?
        issuer.internal_wallet.sign_tx(tx, prev_txs)
      end

      def create_transfer_tx(color_id:, sender:, receiver_address:, amount:, fee_estimator: FeeEstimator::Fixed.new, only_finalized: true)
        receivers = [{ address: receiver_address, amount: amount }]
        create_multi_transfer_tx(
          color_id: color_id,
          sender: sender,
          receivers: receivers,
          fee_estimator: fee_estimator,
          only_finalized: only_finalized
        )
      end

      def create_multi_transfer_tx(color_id:, sender:, receivers:, fee_estimator: FeeEstimator::Fixed.new, only_finalized: true)
        tx = Tapyrus::Tx.new

        amount = receivers.reduce(0) { |sum, r| sum + r[:amount].to_i }
        utxos = sender.internal_wallet.list_unspent(only_finalized, color_id: color_id)
        sum_token, outputs = collect_colored_outputs(utxos, amount)
        fill_input(tx, outputs)

        receivers.each do |r|
          receiver_script = Tapyrus::Script.parse_from_addr(r[:address])
          receiver_colored_script = receiver_script.add_color(color_id)
          tx.outputs << Tapyrus::TxOut.new(value: r[:amount].to_i, script_pubkey: receiver_colored_script)
        end

        fill_change_token(tx, sender, sum_token - amount, color_id)

        fee = fee_estimator.fee(FeeEstimator.dummy_tx(tx))

        utxo_provider = nil

        # Fill inputs for paying fee
        prev_txs = []
        if Glueby.configuration.use_utxo_provider?
          utxo_provider = UtxoProvider.new
          tx, fee, sum_tpc, provided_utxos = utxo_provider.fill_inputs(
            tx,
            target_amount: 0,
            current_amount: 0,
            fee_estimator: fee_estimator
          )
          prev_txs.concat(provided_utxos)
        else
          # TODO: Support the case of increasing fee by adding multiple inputs
          sum_tpc, outputs = sender.internal_wallet.collect_uncolored_outputs(fee, nil, only_finalized)
          fill_input(tx, outputs)
        end

        fill_change_tpc(tx, sender, sum_tpc - fee)
        utxo_provider.wallet.sign_tx(tx, prev_txs) if Glueby.configuration.use_utxo_provider?
        sender.internal_wallet.sign_tx(tx, prev_txs)
      end

      def create_burn_tx(color_id:, sender:, amount: 0, fee_estimator: FeeEstimator::Fixed.new, only_finalized: true)
        tx = Tapyrus::Tx.new

        utxos = sender.internal_wallet.list_unspent(only_finalized, color_id: color_id)
        sum_token, outputs = collect_colored_outputs(utxos, amount)
        fill_input(tx, outputs)

        fill_change_token(tx, sender, sum_token - amount, color_id) if amount.positive?
        fee = fee_estimator.fee(FeeEstimator.dummy_tx(tx))

        provided_utxos = []
        utxo_provider = nil

        if Glueby.configuration.use_utxo_provider?
          utxo_provider = UtxoProvider.new
          # When it burns all the amount of the color id, burn tx is not going to have any output
          # because change outputs are not necessary, though such a transaction is not 'standard' and would be rejected by the Tapyrus node.
          # UtxoProvider#fill_inputs method provides an extra output with a DUST_LIMIT value in this case
          # , so that it created at least one output to the burn tx.
          tx, fee, sum_tpc, provided_utxos = utxo_provider.fill_inputs(
            tx,
            target_amount: 0,
            current_amount: 0,
            fee_estimator: fee_estimator
          )
        else
          sum_tpc, outputs = sender.internal_wallet.collect_uncolored_outputs(fee + DUST_LIMIT, nil, only_finalized)
          fill_input(tx, outputs)
        end
        fill_change_tpc(tx, sender, sum_tpc - fee)
        utxo_provider.wallet.sign_tx(tx, provided_utxos) if Glueby.configuration.use_utxo_provider?
        sender.internal_wallet.sign_tx(tx, provided_utxos)
      end

      def add_split_output(tx, amount, split, script_pubkey)
        if amount < split
          split = amount
          value = 1
        else
          value = (amount/split).to_i
        end
        (split - 1).times { tx.outputs << Tapyrus::TxOut.new(value: value, script_pubkey: script_pubkey) }
        tx.outputs << Tapyrus::TxOut.new(value: amount - value * (split - 1), script_pubkey: script_pubkey)
      end

      def fill_input(tx, outputs)
        outputs.each do |output|
          out_point = Tapyrus::OutPoint.new(output[:txid].rhex, output[:vout])
          tx.inputs << Tapyrus::TxIn.new(out_point: out_point)
        end
      end

      def fill_change_tpc(tx, wallet, change)
        return unless change.positive?

        if Glueby.configuration.use_utxo_provider?
          change_script = Tapyrus::Script.parse_from_addr(UtxoProvider.new.wallet.change_address)
        else
          change_script = Tapyrus::Script.parse_from_addr(wallet.internal_wallet.change_address)
        end

        tx.outputs << Tapyrus::TxOut.new(value: change, script_pubkey: change_script)
      end

      def fill_change_token(tx, wallet, change, color_id)
        return unless change.positive?

        change_script = Tapyrus::Script.parse_from_addr(wallet.internal_wallet.change_address)
        change_colored_script = change_script.add_color(color_id)
        tx.outputs << Tapyrus::TxOut.new(value: change, script_pubkey: change_colored_script)
      end

      # Returns the set of utxos that satisfies the specified amount and has the specified color_id.
      # if amount is not specified or 0, return all utxos with color_id
      # @param results [Array] response of Glueby::Internal::Wallet#list_unspent
      # @param amount [Integer]
      def collect_colored_outputs(results, amount = 0)
        results = results.inject([0, []]) do |sum, output|
          new_sum = sum[0] + output[:amount]
          new_outputs = sum[1] << output
          return [new_sum, new_outputs] if new_sum >= amount && amount.positive?

          [new_sum, new_outputs]
        end
        raise Glueby::Contract::Errors::InsufficientTokens if amount.positive?

        results
      end

      # Add dummy inputs and outputs to tx for issue non-reissuable transaction and nft transaction
      def dummy_issue_tx_from_out_point
        tx = Tapyrus::Tx.new
        receiver_colored_script = Tapyrus::Script.parse_from_payload('21c20000000000000000000000000000000000000000000000000000000000000000bc76a914000000000000000000000000000000000000000088ac'.htb)
        tx.outputs << Tapyrus::TxOut.new(value: 0, script_pubkey: receiver_colored_script)
        FeeEstimator.dummy_tx(tx)
      end

      private

      # The amount of output in funding tx
      # It returns same amount with FeeEstimator::Fixed's fixed fee. Because it is enough for paying fee for consumer
      # transactions of the funding transactions.
      def funding_tx_amount
        FeeEstimator::Fixed.new.fixed_fee
      end
    end
  end
end
