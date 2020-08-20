RSpec.describe 'Glueby::Internal::Wallet' do
  class TestWalletAdapter < Glueby::Internal::Wallet::AbstractWalletAdapter
    def create_wallet; end
    def load_wallet(wallet_id); end
  end

  before do
    Glueby::Internal::Wallet.wallet_adapter = TestWalletAdapter.new
  end

  after do
    Glueby::Internal::Wallet.wallet_adapter = nil
  end

  describe 'create' do
    subject { Glueby::Internal::Wallet.create }
    it { should be_a Glueby::Internal::Wallet }
  end

  describe 'load' do
    subject { Glueby::Internal::Wallet.load(wallet_id) }

    let(:wallet_id) { '0828d0ce8ff358cd0d7b19ac5c43c3bb' }

    it { expect(subject.id).to eq wallet_id }

    context 'if already loaded' do
      let(:error) { Glueby::Internal::Wallet::Errors::WalletAlreadyLoaded }

      it do
        allow(Glueby::Internal::Wallet.wallet_adapter).to receive(:load_wallet).and_raise(error)
        expect(subject.id).to eq wallet_id
      end
    end

    context 'if not initialized' do
      before { Glueby::Internal::Wallet.wallet_adapter = nil }

      it { expect { subject }.to raise_error(Glueby::Internal::Wallet::Errors::ShouldInitializeWalletAdapter) }
    end
  end

  describe 'ShouldInitializeWalletAdapter Error' do
    before do
      Glueby::Internal::Wallet.wallet_adapter = nil
    end

    it 'should raise the error' do
      expect { Glueby::Internal::Wallet.create }.to raise_error(Glueby::Internal::Wallet::Errors::ShouldInitializeWalletAdapter)
    end

  end
end