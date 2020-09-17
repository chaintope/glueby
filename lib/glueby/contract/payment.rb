# frozen_string_literal: true

module Glueby
  module Contract
    # This class can send TPC between wallets.
    #
    # Examples:
    #
    # sender = Glueby::Wallet.load("wallet_id")
    # reciever = Glueby::Wallet.load("wallet_id")
    #                      or
    #            Glueby::Wallet.create
    #
    # Balance of sender and reciever before send
    # sender.internal_wallet.balance
    # => 100_000(tapyrus)
    # reciever.internal_wallet.balance
    # => 0(tapyrus)
    #
    # Send
    # Payment.transfer(sender_wallet: sender, receiver_wallet: reciever, amount: 10_000)
    # sender.internal_wallet.balance
    # => 90_000
    # reciever.internal_wallet.balance
    # => 10_000
    #
    class Payment
      include Glueby::Contract::TxBuilder
      extend Glueby::Contract::TxBuilder

      class << self
        def transfer(sender:, receiver:, amount:, fee_provider: FixedFeeProvider.new)
          raise Glueby::Contract::Errors::InvalidAmount unless amount.positive?

          tx = Tapyrus::Tx.new
          fee = fee_provider.fee(dummy_tx(tx))
          utxos = sender_wallet.internal_wallet.list_unspent

          sum, outputs = collect_uncolored_outputs(utxos, fee + amount)
          fill_input(tx, outputs)

          receiver_script = Tapyrus::Script.parse_from_addr(receiver.internal_wallet.receive_address)
          tx.outputs << Tapyrus::TxOut.new(value: amount, script_pubkey: receiver_script)

          fill_change_tpc(tx, sender, sum - fee - amount)

          tx = sender.internal_wallet.sign_tx(tx)

          Glueby::Internal::RPC.client.sendrawtransaction(tx.to_payload.bth)
        end
      end
    end
  end
end
