RSpec.describe 'Glueby::Contract::Timestamp' do
  describe '#initialize' do
    let(:wallet) { TestWallet.new(internal_wallet) }
    let(:internal_wallet) { TestInternalWallet.new }

    context 'if digest unspport' do
      subject do
        Glueby::Contract::Timestamp.new(
          wallet: wallet,
          content: "01",
          prefix: '',
          digest: nil
        )
      end

      it { expect { subject }.to raise_error(Glueby::Contract::Errors::UnsupportedDigestType) }
    end

    context 'with unsupported timestamp type' do
      subject do
        Glueby::Contract::Timestamp.new(
          wallet: wallet,
          content: 'bar',
          prefix: 'foo',
          digest: :none,
          timestamp_type: :invalid_type
        )
      end

      it { expect { subject }.to raise_error(Glueby::Contract::Errors::InvalidTimestampType) }
    end
  end

  describe '#save!' do
    subject { contract.save! }

    let(:contract) do
      Glueby::Contract::Timestamp.new(
        wallet: wallet,
        content: "\01",
        prefix: ''
      )
    end
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
          txid: 'd49c8038943d37c2723c9c7a1c4ea5c3738a9bad5827ddc41e144ba6aef36db',
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
          amount: 1,
          finalized: true
        }, {
          txid: 'f14b29639483da7c8d17b7b7515da4ff78b91b4b89434e7988ab1bc21ab41377',
          vout: 0,
          script_pubkey: '21c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016bc76a914fc688c091d91789ccda7a27bd8d88be9ae4af58e88ac',
          amount: 100_000,
          finalized: true
        }, {
          txid: '100c4dc65ea4af8abb9e345b3d4cdcc548bb5e1cdb1cb3042c840e147da72fa2',
          vout: 0,
          script_pubkey: '21c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3bc76a9144f15d2203821d7ea719314126b79bd1e530fc97588ac',
          amount: 100_000,
          finalized: true
        }, {
          txid: 'a3f20bc94c8d77c35ba1770116d2b34375475a4194d15f76442636e9f77d50d9',
          vout: 2,
          script_pubkey: '21c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3bc76a9144f15d2203821d7ea719314126b79bd1e530fc97588ac',
          amount: 100_000,
          finalized: true
        }
      ]
    end
    let(:rpc) { double('mock') }

    before do
      allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)
      allow(rpc).to receive(:getnewaddress).and_return('13L2GiUwB3HuyURm81ht6JiQAa8EcBN23H')
      allow(internal_wallet).to receive(:list_unspent).and_return(unspents)
      allow(internal_wallet).to receive(:broadcast).and_return('a01d8a6bf7bef5719ada2b7813c1ce4dabaf8eb4ff22791c67299526793b511c')
    end

    it { expect(subject).to eq 'a01d8a6bf7bef5719ada2b7813c1ce4dabaf8eb4ff22791c67299526793b511c' }
    it 'create transaction' do
      subject
      expect(contract.tx.inputs.size).to eq 1
      expect(contract.tx.outputs.size).to eq 2
      expect(contract.tx.outputs[0].value).to eq 0
      expect(contract.tx.outputs[0].script_pubkey.op_return?).to be_truthy
      expect(contract.tx.outputs[0].script_pubkey.op_return_data.bth).to eq "4bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459a"
      expect(contract.tx.outputs[1].value).to eq 99_990_000
    end

    context 'if already broadcasted' do
      before { contract.save! }

      it { expect { subject }.to raise_error(Glueby::Contract::Errors::TxAlreadyBroadcasted) }
    end

    context 'if digest is :none' do
      let(:contract) do
        Glueby::Contract::Timestamp.new(
          wallet: wallet,
          content: "01",
          prefix: '',
          digest: :none
        )
      end

      it 'create transaction for content that is not digested' do
        subject
        expect(contract.tx.inputs.size).to eq 1
        expect(contract.tx.outputs.size).to eq 2
        expect(contract.tx.outputs[0].value).to eq 0
        expect(contract.tx.outputs[0].script_pubkey.op_return?).to be_truthy
        expect(contract.tx.outputs[0].script_pubkey.op_return_data.bth).to eq '01'
        expect(contract.tx.outputs[1].value).to eq 99_990_000
      end
    end

    context 'if digest is :double_sha256' do
      let(:contract) do
        Glueby::Contract::Timestamp.new(
          wallet: wallet,
          content: "01",
          prefix: '',
          digest: :double_sha256
        )
      end

      it 'create transaction for double sha256 digested content' do
        subject
        expect(contract.tx.inputs.size).to eq 1
        expect(contract.tx.outputs.size).to eq 2
        expect(contract.tx.outputs[0].value).to eq 0
        expect(contract.tx.outputs[0].script_pubkey.op_return?).to be_truthy
        expect(contract.tx.outputs[0].script_pubkey.op_return_data.bth).to eq 'bf3ae3deccfdee0ebf03fc924aea3dad4b1068acdd27e98d9e6cc9a140e589d1'
        expect(contract.tx.outputs[1].value).to eq 99_990_000
      end
    end

    context 'if type is trackable', active_record: true do
      let(:contract) do
        Glueby::Contract::Timestamp.new(
          wallet: wallet,
          content: 'bar',
          prefix: 'foo',
          digest: :none,
          timestamp_type: :trackable
        )
      end

      let(:active_record_wallet) { Glueby::Internal::Wallet::AR::Wallet.find_by(wallet_id: wallet.id) }
      let(:key) { active_record_wallet.keys.create(purpose: :receive) }

      before do
        Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new
        Glueby::Internal::Wallet::AR::Utxo.create(
          txid: '0000000000000000000000000000000000000000000000000000000000000000',
          index: 0,
          value: 100_000_000,
          script_pubkey: key.to_p2pkh.to_hex,
          status: :finalized,
          key: key
        )
      end

      let(:wallet) { Glueby::Wallet.create }
      it 'create pay-to-contract transaction' do
        allow(wallet.internal_wallet).to receive(:broadcast).and_return('a01d8a6bf7bef5719ada2b7813c1ce4dabaf8eb4ff22791c67299526793b511c')
        subject
        expect(contract.tx.inputs.size).to eq 1
        expect(contract.tx.outputs.size).to eq 2
        expect(contract.tx.outputs[0].value).to eq 1_000
        expect(contract.tx.outputs[0].script_pubkey.op_return?).to be_falsy
        expect(contract.tx.outputs[0].script_pubkey.p2pkh?).to be_truthy
        expect(contract.tx.outputs[1].value).to eq 99_989_000
      end
    end

    context 'if use utxo provider' do
      let(:contract) do
        Glueby::Contract::Timestamp.new(
          wallet: wallet,
          content: "\01",
          prefix: '',
          utxo_provider: utxo_provider
        )
      end
      let(:utxo_provider) { Glueby::UtxoProvider.new }
      let(:wallet_adapter) { double(:wallet_adapter) }

      before do
        Glueby::Internal::Wallet.wallet_adapter = wallet_adapter
        allow(wallet_adapter).to receive(:load_wallet)
        allow(utxo_provider).to receive(:wallet).and_return(internal_wallet)
      end

      after { Glueby::Internal::Wallet.wallet_adapter = nil }

      it 'broadcast 2 transactions' do
        expect(internal_wallet).to receive(:broadcast).twice
        subject
      end
    end
  end
end
