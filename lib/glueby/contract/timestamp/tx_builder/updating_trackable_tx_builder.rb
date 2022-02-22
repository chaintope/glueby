module Glueby
  module Contract
    class Timestamp
      class TxBuilder
        class UpdatingTrackableTxBuilder < TrackableTxBuilder
          def set_prev_timestamp_info(timestamp_utxo:, payment_base:, prefix:, data:)
            @prev_timestamp_utxo = timestamp_utxo
            @prev_payment_base = payment_base
            @prev_prefix = prefix
            @prev_data = data
            @txb.add_utxo(to_tapyrusrb_utxo_hash(@prev_timestamp_utxo))
          end

          def sign_tx
            tx = super
            # Generates signature for the remain p2c input.
            sign_to_pay_to_contract_address(tx, @prev_timestamp_utxo, @prev_payment_base, @prev_prefix, @prev_data)
          end

          private

          # TODO: Move into wallet
          # TODO: Add documentation
          def sign_to_pay_to_contract_address(tx, prev_timestamp_utxo, prev_payment_base, prefix, data)
            key = create_pay_to_contract_private_key(prev_payment_base, prefix, data)
            sighash = tx.sighash_for_input(PAY_TO_CONTRACT_INPUT_INDEX, Tapyrus::Script.parse_from_payload(prev_timestamp_utxo[:script_pubkey].htb))

            sig = key.sign(sighash, algo: :schnorr) + [Tapyrus::SIGHASH_TYPE[:all]].pack('C')
            script_sig = Tapyrus::Script.parse_from_payload(Tapyrus::Script.pack_pushdata(sig) + Tapyrus::Script.pack_pushdata(key.pubkey.htb))
            tx.inputs[PAY_TO_CONTRACT_INPUT_INDEX].script_sig = script_sig
            tx
          end

          # TODO: Move into wallet
          # TODO: Add documentation
          # Current implementation is depends on active record wallet adapter
          def create_pay_to_contract_private_key(payment_base, prefix, data)
            group = ECDSA::Group::Secp256k1
            key = Glueby::Internal::Wallet::AR::Key.find_by(public_key: payment_base)
            commitment = create_pay_to_contract_commitment(payment_base, contents: [prefix, data])
            Tapyrus::Key.new(priv_key: ((key.private_key.to_i(16) + commitment) % group.order).to_even_length_hex) # K + commitment
          end
        end
      end
    end
  end
end