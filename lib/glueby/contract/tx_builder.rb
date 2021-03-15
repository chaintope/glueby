# frozen_string_literal: true

module Glueby
  module Contract
    module TxBuilder
      def receive_address(wallet:)
        wallet.receive_address
      end

      # Create new public key, and new transaction that sends TPC to it
      def create_funding_tx(wallet:, amount:, script: nil, fee_provider: FixedFeeProvider.new)
        tx = Tapyrus::Tx.new
        fee = fee_provider.fee(dummy_tx(tx))

        sum, outputs = wallet.internal_wallet.collect_uncolored_outputs(fee + amount)
        fill_input(tx, outputs)

        receiver_script = script ? script : Tapyrus::Script.parse_from_addr(wallet.internal_wallet.receive_address)
        tx.outputs << Tapyrus::TxOut.new(value: amount, script_pubkey: receiver_script)

        fill_change_tpc(tx, wallet, sum - fee - amount)
        wallet.internal_wallet.sign_tx(tx)
      end

      def create_issue_tx_for_reissuable_token(funding_tx:, issuer:, amount:, fee_provider: FixedFeeProvider.new)
        tx = Tapyrus::Tx.new

        out_point = Tapyrus::OutPoint.from_txid(funding_tx.txid, 0)
        tx.inputs << Tapyrus::TxIn.new(out_point: out_point)
        output = funding_tx.outputs.first

        receiver_script = Tapyrus::Script.parse_from_payload(output.script_pubkey.to_payload)
        color_id = Tapyrus::Color::ColorIdentifier.reissuable(receiver_script)
        receiver_colored_script = receiver_script.add_color(color_id)
        tx.outputs << Tapyrus::TxOut.new(value: amount, script_pubkey: receiver_colored_script)

        fee = fee_provider.fee(dummy_tx(tx))
        fill_change_tpc(tx, issuer, output.value - fee)
        prev_txs = [{
          txid: funding_tx.txid,
          vout: 0,
          scriptPubKey: output.script_pubkey.to_hex,
          amount: output.value
        }]
        issuer.internal_wallet.sign_tx(tx, prev_txs)
      end

      def create_issue_tx_for_non_reissuable_token(issuer:, amount:, fee_provider: FixedFeeProvider.new)
        create_issue_tx_from_out_point(token_type: Tapyrus::Color::TokenTypes::NON_REISSUABLE, issuer: issuer, amount: amount, fee_provider: fee_provider)
      end

      def create_issue_tx_for_nft_token(issuer:, fee_provider: FixedFeeProvider.new)
        create_issue_tx_from_out_point(token_type: Tapyrus::Color::TokenTypes::NFT, issuer: issuer, amount: 1, fee_provider: fee_provider)
      end

      def create_issue_tx_from_out_point(token_type:, issuer:, amount:, fee_provider: FixedFeeProvider.new)
        tx = Tapyrus::Tx.new

        fee = fee_provider.fee(dummy_issue_tx_from_out_point)
        sum, outputs = issuer.internal_wallet.collect_uncolored_outputs(fee)
        fill_input(tx, outputs)

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
        tx.outputs << Tapyrus::TxOut.new(value: amount, script_pubkey: receiver_colored_script)

        fill_change_tpc(tx, issuer, sum - fee)
        issuer.internal_wallet.sign_tx(tx)
      end

      def create_reissue_tx(funding_tx:, issuer:, amount:, color_id:, fee_provider: FixedFeeProvider.new)
        tx = Tapyrus::Tx.new

        out_point = Tapyrus::OutPoint.from_txid(funding_tx.txid, 0)
        tx.inputs << Tapyrus::TxIn.new(out_point: out_point)
        output = funding_tx.outputs.first

        receiver_script = Tapyrus::Script.parse_from_payload(output.script_pubkey.to_payload)
        receiver_colored_script = receiver_script.add_color(color_id)
        tx.outputs << Tapyrus::TxOut.new(value: amount, script_pubkey: receiver_colored_script)

        fee = fee_provider.fee(dummy_tx(tx))
        fill_change_tpc(tx, issuer, output.value - fee)
        prev_txs = [{
          txid: funding_tx.txid,
          vout: 0,
          scriptPubKey: output.script_pubkey.to_hex,
          amount: output.value
        }]
        issuer.internal_wallet.sign_tx(tx, prev_txs)
      end

      def create_transfer_tx(color_id:, sender:, receiver_address:, amount:, fee_provider: FixedFeeProvider.new)
        tx = Tapyrus::Tx.new

        utxos = sender.internal_wallet.list_unspent
        sum_token, outputs = collect_colored_outputs(utxos, color_id, amount)
        fill_input(tx, outputs)

        receiver_script = Tapyrus::Script.parse_from_addr(receiver_address)
        receiver_colored_script = receiver_script.add_color(color_id)
        tx.outputs << Tapyrus::TxOut.new(value: amount, script_pubkey: receiver_colored_script)

        fill_change_token(tx, sender, sum_token - amount, color_id)

        fee = fee_provider.fee(dummy_tx(tx))
        sum_tpc, outputs = sender.internal_wallet.collect_uncolored_outputs(fee)
        fill_input(tx, outputs)

        fill_change_tpc(tx, sender, sum_tpc - fee)
        sender.internal_wallet.sign_tx(tx)
      end

      def create_burn_tx(color_id:, sender:, amount: 0, fee_provider: FixedFeeProvider.new)
        tx = Tapyrus::Tx.new

        utxos = sender.internal_wallet.list_unspent
        sum_token, outputs = collect_colored_outputs(utxos, color_id, amount)
        fill_input(tx, outputs)

        fill_change_token(tx, sender, sum_token - amount, color_id) if amount.positive?

        fee = fee_provider.fee(dummy_tx(tx))

        dust = 600 # in case that the wallet has output which has just fee amount.
        sum_tpc, outputs = sender.internal_wallet.collect_uncolored_outputs(fee + dust)
        fill_input(tx, outputs)

        fill_change_tpc(tx, sender, sum_tpc - fee)
        sender.internal_wallet.sign_tx(tx)
      end

      def fill_input(tx, outputs)
        outputs.each do |output|
          out_point = Tapyrus::OutPoint.new(output[:txid].rhex, output[:vout])
          tx.inputs << Tapyrus::TxIn.new(out_point: out_point)
        end
      end

      def fill_change_tpc(tx, wallet, change)
        return unless change.positive?

        change_script = Tapyrus::Script.parse_from_addr(wallet.internal_wallet.change_address)
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
      # @param color_id [Tapyrus::Color::ColorIdentifier] color identifier
      # @param amount [Integer]
      def collect_colored_outputs(results, color_id, amount = 0)
        results = results.inject([0, []]) do |sum, output|
          next sum unless output[:color_id] == color_id.to_hex

          new_sum = sum[0] + output[:amount]
          new_outputs = sum[1] << output
          return [new_sum, new_outputs] if new_sum >= amount && amount.positive?

          [new_sum, new_outputs]
        end
        raise Glueby::Contract::Errors::InsufficientTokens if amount.positive?

        results
      end

      # Add dummy inputs and outputs to tx
      def dummy_tx(tx)
        dummy = Tapyrus::Tx.parse_from_payload(tx.to_payload)

        # dummy input for tpc
        out_point = Tapyrus::OutPoint.new('00' * 32, 0)
        dummy.inputs << Tapyrus::TxIn.new(out_point: out_point)

        # Add script_sig to all intpus
        dummy.inputs.each do |input|
          input.script_sig = Tapyrus::Script.parse_from_payload('000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'.htb)
        end

        # dummy output to return change
        change_script = Tapyrus::Script.to_p2pkh('0000000000000000000000000000000000000000')
        dummy.outputs << Tapyrus::TxOut.new(value: 0, script_pubkey: change_script)
        dummy
      end

      # Add dummy inputs and outputs to tx for issue non-reissuable transaction and nft transaction
      def dummy_issue_tx_from_out_point
        tx = Tapyrus::Tx.new
        receiver_colored_script = Tapyrus::Script.parse_from_payload('21c20000000000000000000000000000000000000000000000000000000000000000bc76a914000000000000000000000000000000000000000088ac'.htb)
        tx.outputs << Tapyrus::TxOut.new(value: 0, script_pubkey: receiver_colored_script)
        dummy_tx(tx)
      end
    end
  end
end
