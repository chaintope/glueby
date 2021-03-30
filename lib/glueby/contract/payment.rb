# frozen_string_literal: true

module Glueby
  module Contract
    # This class can send TPC between wallets.
    #
    # Examples:
    #
    # sender = Glueby::Wallet.load("wallet_id")
    # receiver = Glueby::Wallet.load("wallet_id")
    #                      or
    #            Glueby::Wallet.create
    #
    # Use `Glueby::Internal::Wallet#receive_address` to generate the address of a receiver
    # receiver.internal_wallet.receive_address
    # => '1CY6TSSARn8rAFD9chCghX5B7j4PKR8S1a'
    #
    # Balance of sender and receiver before send
    # sender.balances[""]
    # => 100_000(tapyrus)
    # receiver.balances[""]
    # => 0(tapyrus)
    #
    # Send
    # Payment.transfer(sender: sender, receiver_address: '1CY6TSSARn8rAFD9chCghX5B7j4PKR8S1a', amount: 10_000)
    # sender.balances[""]
    # => 90_000
    # receiver.balances[""]
    # => 10_000
    #
    class Payment
      extend Glueby::Contract::TxBuilder

      class << self
        def transfer(sender:, receiver_address:, amount:, fee_provider: FixedFeeProvider.new)
          raise Glueby::Contract::Errors::InvalidAmount unless amount.positive?

          tx = Tapyrus::Tx.new
          dummy_fee = fee_provider.fee(dummy_tx(tx))

          sum, outputs = sender.internal_wallet.collect_uncolored_outputs(dummy_fee + amount)
          fill_input(tx, outputs)

          receiver_script = Tapyrus::Script.parse_from_addr(receiver_address)
          tx.outputs << Tapyrus::TxOut.new(value: amount, script_pubkey: receiver_script)

          fee = fee_provider.fee(tx)

          fill_change_tpc(tx, sender, sum - fee - amount)

          tx = sender.internal_wallet.sign_tx(tx)

          sender.internal_wallet.broadcast(tx)
        end
      end
    end
  end
end
