RSpec.describe 'Glueby::Internal::Wallet' do
  class TestWalletAdapter < Glueby::Internal::Wallet::AbstractWalletAdapter
    def create_wallet; end
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

  describe 'ShouldInitializeWalletAdapter Error' do
    before do
      Glueby::Internal::Wallet.wallet_adapter = nil
    end

    it 'should raise the error' do
      expect { Glueby::Internal::Wallet.create }.to raise_error(Glueby::Internal::Wallet::Errors::ShouldInitializeWalletAdapter)
    end

  end
end