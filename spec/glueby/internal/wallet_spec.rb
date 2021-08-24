RSpec.describe 'Glueby::Internal::Wallet' do
  class self::TestWalletAdapter < Glueby::Internal::Wallet::AbstractWalletAdapter
    def create_wallet(wallet_id = nil)
      wallet_id || 'created_wallet_id'
    end
    def load_wallet(wallet_id); end
  end

  before do
    Glueby::Internal::Wallet.wallet_adapter = self.class::TestWalletAdapter.new
  end

  after do
    Glueby::Internal::Wallet.wallet_adapter = nil
  end

  describe 'create' do
    subject { Glueby::Internal::Wallet.create }
    it { should be_a Glueby::Internal::Wallet }
    it 'has wallet id' do
      expect(subject.id).to eq 'created_wallet_id'
    end

    context 'wallet_id is specified' do
      subject { Glueby::Internal::Wallet.create('specified_wallet_id') }
      it { should be_a Glueby::Internal::Wallet }
      it 'has wallet id' do
        expect(subject.id).to eq 'specified_wallet_id'
      end
    end
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

    context 'if not exist' do
      let(:error) { Glueby::Internal::Wallet::Errors::WalletNotFound }

      it do
        allow(Glueby::Internal::Wallet.wallet_adapter).to receive(:load_wallet).and_raise(error)
        expect { subject }.to raise_error(Glueby::Internal::Wallet::Errors::WalletNotFound)
      end
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

  describe 'collect_uncolored_outputs' do
    before { allow(internal_wallet).to receive(:list_unspent).and_return(unspents) }

    subject { wallet.internal_wallet.collect_uncolored_outputs(amount, nil, only_finalized) }

    let(:amount) { 150_000_000 }
    let(:only_finalized) { true }
    let(:wallet) { TestWallet.new(internal_wallet) }
    let(:internal_wallet) { TestInternalWallet.new }
    let(:unspents) do
      [
        {
          txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
          script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
          vout: 0,
          amount: 100_000_000,
          finalized: false
        }, {
          txid: '1d49c8038943d37c2723c9c7a1c4ea5c3738a9bad5827ddc41e144ba6aef36db',
          script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
          vout: 1,
          amount: 100_000_000,
          finalized: true
        }, {
          txid: '1d49c8038943d37c2723c9c7a1c4ea5c3738a9bad5827ddc41e144ba6aef36db',
          script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
          vout: 2,
          amount: 50_000_000,
          finalized: true
        }, {
          txid: '864247cd4cae4b1f5bd3901be9f7a4ccba5bdea7db1d8bbd78b944da9cf39ef5',
          vout: 0,
          script_pubkey: '21c3eb2b846463430b7be9962843a97ee522e3dc0994a0f5e2fc0aa82e20e67fe893bc76a914bfeca7aed62174a7c60ebc63c7bd797bad46157a88ac',
          color_id: 'c3eb2b846463430b7be9962843a97ee522e3dc0994a0f5e2fc0aa82e20e67fe893',
          amount: 1,
          finalized: true
        }, {
          txid: 'f14b29639483da7c8d17b7b7515da4ff78b91b4b89434e7988ab1bc21ab41377',
          vout: 0,
          script_pubkey: '21c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016bc76a914fc688c091d91789ccda7a27bd8d88be9ae4af58e88ac',
          color_id: 'c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016',
          amount: 100_000,
          finalized: true
        }, {
          txid: '100c4dc65ea4af8abb9e345b3d4cdcc548bb5e1cdb1cb3042c840e147da72fa2',
          vout: 0,
          script_pubkey: '21c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3bc76a9144f15d2203821d7ea719314126b79bd1e530fc97588ac',
          color_id: 'c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3',
          amount: 100_000,
          finalized: true
        }, {
          txid: 'a3f20bc94c8d77c35ba1770116d2b34375475a4194d15f76442636e9f77d50d9',
          vout: 2,
          script_pubkey: '21c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3bc76a9144f15d2203821d7ea719314126b79bd1e530fc97588ac',
          color_id: 'c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3',
          amount: 100_000,
          finalized: true
        },
      ]
    end

    it { expect(subject[0]).to eq 200_000_000 }
    it { expect(subject[1].size).to eq 2 }

    context 'with unconfirmed' do
      let(:amount) { 250_000_000 }
      let(:only_finalized) { false }

      it do
        expect(internal_wallet).to receive(:list_unspent).with(false, nil).and_return(unspents)
        expect(subject[0]).to eq 250_000_000
        expect(subject[1].size).to eq 3
      end
    end

    context 'does not have enough tpc' do
      let(:amount) { 250_000_001 }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InsufficientFunds }
    end
  end
end