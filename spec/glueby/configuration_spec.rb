RSpec.describe 'Glueby::Configuration' do

  describe 'wallet_adapter=' do
    subject do
      Glueby.configure do |config|
        config.wallet_adapter = adapter
      end
    end

    context 'core' do
      let(:adapter) { :core }
      it 'set core adapter' do
        subject
        expect(Glueby::Internal::Wallet.wallet_adapter).to be_kind_of(Glueby::Internal::Wallet::TapyrusCoreWalletAdapter)
      end
    end

    context 'activerecord' do
      let(:adapter) { :activerecord }
      it 'set activ erecord adapter' do
        subject
        expect(Glueby::Internal::Wallet.wallet_adapter).to be_kind_of(Glueby::Internal::Wallet::ActiveRecordWalletAdapter)
      end
    end
    
    context 'mysql' do
      let(:adapter) { :mysql }
      it 'set mysql adapter' do
        subject
        expect(Glueby::Internal::Wallet.wallet_adapter).to be_kind_of(Glueby::Internal::Wallet::MySQLWalletAdapter)
      end
    end

    context 'invalid adapter' do
      let(:adapter) { :postgres }
      it { expect{ subject}.to raise_error(RuntimeError, 'Not implemented') }
    end
  end

  # describe "rpc_config=" do
  #   subject do
  #     Glueby.configure do |config|
  #       config.rpc_config = new_config
  #     end
  #   end

  #   let(:new_config) do
  #     {
  #       schema: 'http',
  #       host: '127.0.0.1', 
  #       port: 9999, 
  #       user: 'testuser', 
  #       password: 'testpassword'
  #     }
  #   end

  #   it do
  #     allow(Glueby::Internal::RPC).to receive(:configure)
  #     subject
  #     expect(Glueby::Internal::RPC).to have_received(:configure).with(new_config).once
  #   end
  # end

  describe "fee_provider_config=" do
    subject do
      Glueby.configure do |config|
        config.fee_provider_config = {
          fixed_fee: 2_000,
          utxo_pool_size: 200 
        }
      end
    end

    it do
      subject
      expect(Glueby::FeeProvider.config[:fixed_fee]).to eq 2_000
      expect(Glueby::FeeProvider.config[:utxo_pool_size]).to eq 200
    end
  end

  # describe "utxo_provider_config" do
  #   subject do
  #     Glueby.configure do |config|
  #       config.utxo_provider_config = new_config
  #     end
  #   end

  #   let(:new_config) do
  #     {
  #       default_value: 600,
  #       utxo_pool_size: 100
  #     }
  #   end

  #   it do
  #     subject
  #     expect(Glueby::UtxoProvider.config[:default_value]).to eq 600
  #     expect(Glueby::UtxoProvider.config[:utxo_pool_size]).to eq 100
  #   end
  # end

  # describe "default_fixed_fee=" do
  #   subject do
  #     Glueby.configure do |config|
  #       config.default_fixed_fee = 1000
  #     end
  #   end

  #   # after do
  #   #   Glueby::Contract::FeeEstimator::Fixed.default_fixed_fee = Glueby::Contract::FeeEstimator::Fixed::DEFAULT_FEE
  #   # end

  #   it do
  #     subject
  #     expect(Glueby::Contract::FeeEstimator::Fixed.default_fixed_fee).to eq 1_000
  #   end
  # end

  # describe "default_fee_rate=" do
  #   subject do
  #     Glueby.configure do |config|
  #       config.default_fee_rate = 200
  #     end
  #   end

  #   # after do
  #   #   Glueby::Contract::FeeEstimator::Auto.default_fee_rate = Glueby::Contract::FeeEstimator::Auto::DEFAULT_FEE_RATE
  #   # end

  #   it do
  #     subject
  #     expect(Glueby::Contract::FeeEstimator::Auto.default_fee_rate).to eq 200
  #   end
  # end
end
