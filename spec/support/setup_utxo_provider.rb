# frozen_string_literal: true

RSpec.shared_context 'setup utxo provider' do
  let(:default_fixed_fee) { 2_000 }
  let(:default_value) { 4_000 }
  let(:utxo_pool_size) { 20 }

  before do
    Glueby::Contract::FeeEstimator::Fixed.default_fixed_fee = default_fixed_fee
    Glueby.configure do |config|
      config.enable_utxo_provider!
      config.utxo_provider_config = {
        default_value: default_value,
        utxo_pool_size: utxo_pool_size
      }
    end
    # create UTXOs in the UTXO pool
    utxo_provider = Glueby::UtxoProvider.new
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
