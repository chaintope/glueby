RSpec.shared_context 'setup fee provider' do
  before do
    Glueby.configuration.fee_provider_bears!
    # create UTXOs in the UTXO pool
    fee_provider = Glueby::FeeProvider.new
    wallet = fee_provider.wallet
    process_block(to_address: wallet.receive_address)
    Rake.application['glueby:fee_provider:manage_utxo_pool'].execute
  end

  after do
    Glueby.configuration.disable_fee_provider_bears!
  end
end