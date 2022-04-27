# frozen_string_literal: true

RSpec.shared_context 'setup utxo provider' do
  before do
    Glueby::Contract::FeeEstimator::Fixed.default_fixed_fee = 2000
    Glueby.configure do |config|
      config.enable_utxo_provider!
      config.utxo_provider_config = {
        default_value: 4_000,
        utxo_pool_size: 20
      }
    end
    # create UTXOs in the UTXO pool
    utxo_provider = Glueby::UtxoProvider.instance
    wallet = utxo_provider.wallet
    process_block(to_address: wallet.receive_address)
    Rake.application['glueby:utxo_provider:manage_utxo_pool'].execute
    process_block # finalize UTXOs in the pool
  end

  after do
    Glueby.configure do |config|
      config.disable_utxo_provider!
      config.utxo_provider_config = {
        default_value: 1_000,
        utxo_pool_size: 20
      }
    end
    Glueby::Contract::FeeEstimator::Fixed.default_fixed_fee = nil
  end
end
