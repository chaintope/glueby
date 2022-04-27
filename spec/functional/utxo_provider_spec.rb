RSpec.describe 'UtxoProvider', functional: true, active_record: true do
  let(:pool_size) { 20 }
  let(:default_value) { 4_000 }
  let(:utxo_provider) { Glueby::UtxoProvider.instance }
  let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new }
  let(:fee_estimator_for_manage) { fee_estimator }
  before do
    Glueby.configuration.wallet_adapter = :activerecord
    Glueby::Contract::FeeEstimator::Fixed.default_fixed_fee = 2000
    Glueby.configure do |config|
      config.enable_utxo_provider!
      config.utxo_provider_config = {
        default_value: default_value,
        utxo_pool_size: pool_size,
        fee_estimator: fee_estimator,
        fee_estimator_for_manage: fee_estimator_for_manage
      }
    end

    # create UTXOs in the UTXO pool
    process_block(to_address: utxo_provider.wallet.receive_address)
  end

  after do
    Glueby.configure do |config|
      config.disable_utxo_provider!
      config.utxo_provider_config = {
        default_value: 1_000,
        utxo_pool_size: 20
      }
    end
    Glueby::Internal::Wallet.wallet_adapter = nil
    Glueby::Contract::FeeEstimator::Fixed.default_fixed_fee = nil
  end

  subject do
    Rake.application['glueby:utxo_provider:manage_utxo_pool'].execute
    process_block # finalize UTXOs in the pool
  end

  shared_examples 'the utxo provider provides utxos to the pool' do
    it 'provides utxos to the pool' do
      subject

      current_pool_size = utxo_provider
                            .wallet
                            .list_unspent
                            .select { |o| !o[:color_id] && o[:amount] == default_value }
                            .size
      expect(current_pool_size).to eq (pool_size)
    end
  end

  it_behaves_like 'the utxo provider provides utxos to the pool'

  context 'utxo_pool_size is 53(This is max size under 2000 tapyrus fee)' do
    let(:pool_size) { 53 }
    it_behaves_like 'the utxo provider provides utxos to the pool'
  end

  context 'utxo_pool_size is over maximum size' do
    let(:pool_size) { 54 }
    it { expect { subject }.to raise_error(Tapyrus::RPC::Error) }
  end

  context 'use Glueby::Contract::FeeEstimator::Auto for manage utxo pool' do
    let(:fee_estimator_for_manage) { Glueby::Contract::FeeEstimator::Auto.new }

    context 'utxo_pool_size is 100(This is enough over max size under 2000 tapyrus fee)' do
      let(:pool_size) { 100 }
      it_behaves_like 'the utxo provider provides utxos to the pool'
    end
  end
end