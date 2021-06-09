RSpec.shared_context 'setup fee provider' do
  before do
    # create UTXOs in the UTXO pool
    fee_provider = Glueby::FeeProvider.new
    wallet = fee_provider.wallet
    process_block(to_address: wallet.receive_address)
    Rake.application['glueby:fee_provider:manage_utxo_pool'].execute
    Glueby.configuration.fee_provider_bears!
  end

  after do
    Glueby.configuration.disable_fee_provider_bears!
  end
end