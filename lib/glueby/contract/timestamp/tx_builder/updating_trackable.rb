module Glueby
  module Contract
    class Timestamp
      module TxBuilder
        class UpdatingTrackable < Trackable
          def set_prev_timestamp_info(timestamp_utxo:, payment_base:, prefix:, data:)
            @prev_timestamp_utxo = timestamp_utxo
            @prev_payment_base = payment_base
            @prev_prefix = prefix
            @prev_data = data
            @txb.add_utxo(@prev_timestamp_utxo)
          end

          def build
            tx = super

            # Generates signature for the remain p2c input.
            @wallet.internal_wallet.sign_to_pay_to_contract_address(
              tx,
              @prev_timestamp_utxo,
              @prev_payment_base,
              [@prev_prefix, @prev_data].join
            )
          end
        end
      end
    end
  end
end