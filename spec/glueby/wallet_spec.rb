RSpec.describe 'Glueby::Wallet' do
  class TestWalletAdapter < Glueby::Wallet::AbstractWalletAdapter
    def create_wallet; end
  end

  before do
    Glueby::Wallet.wallet_adapter = TestWalletAdapter.new
  end

  describe 'create' do
    subject { Glueby::Wallet.create }
    it { should be_a Glueby::Wallet }
  end

  describe 'ShouldInitializeWalletAdapter Error' do
    before do
      Glueby::Wallet.wallet_adapter = nil
    end

    it 'should raise the error' do
      expect { Glueby::Wallet.create }.to raise_error(Glueby::Wallet::Errors::ShouldInitializeWalletAdapter)
    end

  end
end