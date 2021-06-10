# frozen_string_literal: true

RSpec.describe 'Glueby::Internal::Wallet::ActiveRecordWalletAdapter', active_record: true do
  let(:adapter) { Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new }
  let(:wallet) { Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: '00000000000000000000000000000000') }

  describe '#create_wallet' do
    subject { adapter.create_wallet }

    it { expect { subject }.to change { Glueby::Internal::Wallet::AR::Wallet.count }.from(0).to(1) }

    context 'specify wallet_id' do
      subject { adapter.create_wallet('wallet') }

      it 'create a new wallet with the wallet_id' do
        expect { subject }.to change { Glueby::Internal::Wallet::AR::Wallet.count }.from(0).to(1)
        expect(Glueby::Internal::Wallet::AR::Wallet.find_by(wallet_id: 'wallet')).not_to be_nil
      end

      context 'wallet_id is already exist' do
        before do
          adapter.create_wallet('wallet')
        end

        it 'raise an error' do
          expect { subject }.to raise_error(error=Glueby::Internal::Wallet::Errors::WalletAlreadyCreated, message="wallet_id 'wallet' is already exists")
        end
      end

      context 'as nil' do
        subject { adapter.create_wallet(nil) }

        it 'create a new wallet with random wallet_id' do
          expect { subject }.to change { Glueby::Internal::Wallet::AR::Wallet.count }.from(0).to(1)
          expect(Glueby::Internal::Wallet::AR::Wallet.first.wallet_id).to match(/[0-9a-f]{32}/)
        end
      end
    end
  end

  describe '#load_wallet' do
    subject { adapter.load_wallet(wallet_id) }

    let(:wallet_id) { '0828d0ce8ff358cd0d7b19ac5c43c3bb' }

    context 'wallet is exists' do
      before do
        adapter.create_wallet(wallet_id)
      end

      it 'never raise errors' do
        expect { subject }.not_to raise_error
      end
    end

    context 'wallet is not exists' do
      it 'raise an error' do
        expect { subject }.to raise_error(Glueby::Internal::Wallet::Errors::WalletNotFound, "Wallet #{wallet_id} does not found")
      end
    end
  end

  describe '#delete_wallet' do
    it do
      wallet_id = adapter.create_wallet
      expect { adapter.delete_wallet(wallet_id) }.to change { Glueby::Internal::Wallet::AR::Wallet.count }.from(1).to(0)
    end
  end

  describe '#wallets' do
    subject { adapter.wallets }

    before do
      Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: '00000000000000000000000000000001')
      Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: '00000000000000000000000000000003')
      Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: '00000000000000000000000000000002')
    end

    it { expect(subject).to eq ['00000000000000000000000000000001', '00000000000000000000000000000002', '00000000000000000000000000000003'] }
  end

  describe '#balance' do
    subject { adapter.balance(wallet.wallet_id, only_finalized) }

    let(:other_wallet) { Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: adapter.create_wallet) }
    let(:only_finalized) { true }
    let(:key1) { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key1, purpose: :receive, wallet: wallet) }
    let(:private_key1) { '1000000000000000000000000000000000000000000000000000000000000000' }
    let(:key2) { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key2, purpose: :receive, wallet: wallet) }
    let(:private_key2) { '2000000000000000000000000000000000000000000000000000000000000000' }
    let(:key3) { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key3, purpose: :receive, wallet: other_wallet) }
    let(:private_key3) { '3000000000000000000000000000000000000000000000000000000000000000' }

    before do
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000000',
        index: 0,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a9140ff36d308d250261c518f2db838f12775476a49788ac',
        value: 1,
        status: :broadcasted,
        key: key1
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000000',
        index: 1,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a914f9cfb93abedaef5b725c986efb31cca730bc0b3d88ac',
        value: 2,
        status: :finalized,
        key: key2
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000000',
        index: 2,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a914f9cfb93abedaef5b725c986efb31cca730bc0b3d88ac',
        value: 3,
        status: :finalized,
        key: key2
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000000',
        index: 3,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91430de67b49d3ce43f8d0948f395ed7a8ad9a584e388ac',
        value: 4,
        status: :init,
        key: key3
      )
    end

    context 'finalized only' do
      it { is_expected.to eq 5 }
    end

    context 'with unconfirmed' do
      let(:only_finalized) { false }
      it { is_expected.to eq 6 }
    end
  end

  describe '#list_unspent' do
    subject { adapter.list_unspent(wallet.wallet_id, only_finalized) }

    let(:other_wallet) { Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: adapter.create_wallet) }
    let(:only_finalized) { true }
    let(:key1) { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key1, purpose: :receive, wallet: wallet) }
    let(:private_key1) { '1000000000000000000000000000000000000000000000000000000000000000' }
    let(:key2) { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key2, purpose: :receive, wallet: wallet) }
    let(:private_key2) { '2000000000000000000000000000000000000000000000000000000000000000' }
    let(:key3) { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key3, purpose: :receive, wallet: other_wallet) }
    let(:private_key3) { '3000000000000000000000000000000000000000000000000000000000000000' }

    before do
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000001',
        index: 0,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a9140ff36d308d250261c518f2db838f12775476a49788ac',
        value: 1,
        status: :broadcasted,
        key: key1
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000002',
        index: 1,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a914f9cfb93abedaef5b725c986efb31cca730bc0b3d88ac',
        value: 2,
        status: :finalized,
        key: key2
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000003',
        index: 2,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a914f9cfb93abedaef5b725c986efb31cca730bc0b3d88ac',
        value: 3,
        status: :finalized,
        key: key2
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000004',
        index: 3,
        script_pubkey: '21c1ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91430de67b49d3ce43f8d0948f395ed7a8ad9a584e388ac',
        value: 4,
        status: :init,
        key: key3
      )
    end

    context 'finalized only' do
      it { expect(subject.count).to eq 2 }
      it { expect(subject[0][:vout]).to eq 1 }
      it { expect(subject[0][:finalized]).to be_truthy }
      it { expect(subject[1][:vout]).to eq 2 }
      it { expect(subject[1][:finalized]).to be_truthy }
    end

    context 'with unconfirmed' do
      let(:only_finalized) { false }

      it { expect(subject.count).to eq 3 }
      it { expect(subject[0][:vout]).to eq 0 }
      it { expect(subject[0][:finalized]).to be_falsy }
      it { expect(subject[1][:vout]).to eq 1 }
      it { expect(subject[1][:finalized]).to be_truthy }
      it { expect(subject[2][:vout]).to eq 2 }
      it { expect(subject[2][:finalized]).to be_truthy }
    end
  end

  describe '#receive_address' do
    subject { adapter.receive_address(wallet.wallet_id) }

    it { expect { subject }.to change { wallet.keys.where(purpose: :receive).count }.from(0).to(1) }
    it { expect { subject }.not_to change { wallet.keys.where(purpose: :change).count } }
    it { expect { Tapyrus.decode_base58_address(subject) }.not_to raise_error }
  end

  describe '#change_address' do
    subject { adapter.change_address(wallet.wallet_id) }

    it { expect { subject }.to change { wallet.keys.where(purpose: :change).count }.from(0).to(1) }
    it { expect { subject }.not_to change { wallet.keys.where(purpose: :receive).count } }
    it { expect { Tapyrus.decode_base58_address(subject) }.not_to raise_error }
  end

  describe '#create_pubkey' do
    subject do
      pubkey = adapter.create_pubkey(wallet.wallet_id)
      pubkey.fully_valid_pubkey?
    end

    it { expect { subject }.to change { wallet.keys.count }.from(0).to(1) }
    it { expect(subject).to be_truthy }
  end

  describe '#get_addresses' do
    subject do 
      adapter.get_addresses(wallet.wallet_id)
    end

    before do
      adapter.receive_address(wallet.wallet_id)
      adapter.receive_address(wallet.wallet_id)
    end

    it { expect(subject.count).to eq 2 }
    it { expect(Tapyrus.valid_address?(subject[0])).to be_truthy }
    it { expect(Tapyrus.valid_address?(subject[1])).to be_truthy }
  end
end
