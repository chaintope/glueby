require "bundler/setup"
require "glueby"
require "tapyrus"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

class TestWallet
  attr_reader :internal_wallet

  def initialize(internal_wallet)
    @internal_wallet = internal_wallet
  end
end

class TestInternalWallet
  def receive_address
    '1DBgMCNBdjQ1Ntz1vpwx2HMYJmc9kw88iT'
  end

  def list_unspent
    []
  end

  def change_address
    '1LUMPgobnSdbaA4iaikHKjCDLHveWYUSt5'
  end

  def sign_tx(tx, _prevtxs = [])
    tx
  end

  def collect_uncolored_outputs(amount)
    utxos = list_unspent

    utxos.inject([0, []]) do |sum, output|
      next sum if output[:color_id]

      new_sum = sum[0] + output[:amount]
      new_outputs = sum[1] << output
      return [new_sum, new_outputs] if new_sum >= amount

      [new_sum, new_outputs]
    end
    raise Glueby::Contract::Errors::InsufficientFunds
  end
end
