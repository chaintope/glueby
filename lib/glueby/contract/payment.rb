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
      class << self
        def transfer(sender:, receiver_address:, amount:, fee_estimator: FeeEstimator::Fixed.new)
          raise Glueby::Contract::Errors::InvalidAmount unless amount.positive?

          txb = Internal::ContractBuilder.new(
            sender_wallet: sender.internal_wallet,
            fee_estimator: fee_estimator
          )

          _sum, outputs = sender.internal_wallet.collect_uncolored_outputs(txb.dummy_fee + amount)
          outputs.each do |utxo|
            txb.add_utxo(utxo)
          end

          txb.pay(receiver_address, amount)

          sender.internal_wallet.broadcast(txb.build)
        end
      end
    end
  end
end
