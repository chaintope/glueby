RSpec.describe 'Glueby::UtxoProvider', active_record: true do
  let(:provider) { Glueby::UtxoProvider.new }
  let(:wallet) { TestWallet.new(internal_wallet) }
  let(:internal_wallet) { TestInternalWallet.new }
  before do
    Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new
  end

  describe '#get_utxo' do
    subject { provider.get_utxo(script_pubkey, value) }

    let(:value) { 2_000 }
    let(:script_pubkey) { Tapyrus::Script.parse_from_payload("76a91457dd450aed53d4e35d3555a24ae7dbf3e08a78ec88ac".htb) }
    let(:key) do
      wallet = Glueby::Internal::Wallet::AR::Wallet.find_by(wallet_id: provider.wallet.id)
      wallet.keys.create(purpose: :receive)
    end

    before do
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        index: 0,
        script_pubkey: '76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
        key: key,
        value: 12_000, # need fee(10_000) + value(2_000)
        status: :finalized
      )
    end

    it do
      expect(subject[0].inputs.size).to eq 1
      expect(subject[0].inputs.first.out_point.txid).to eq 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
      expect(subject[0].inputs.first.out_point.index).to eq 0
      expect(subject[0].outputs.size).to eq 1
      expect(subject[0].outputs.first.script_pubkey).to eq script_pubkey
      expect(subject[0].outputs.first.value).to eq 2_000
      expect(subject[1]).to eq  0
    end

    context 'does not have enough funds' do
      let(:value) { 2_001 }
      it { expect { subject }.to raise_error(Glueby::Contract::Errors::InsufficientFunds) }
    end
  end

  describe "#validate_config!" do
    subject { provider.send(:validate_config!) }

    context 'has no configuration' do
      it { expect { subject }.not_to raise_error }
    end

    context 'valid configuration' do
      before { Glueby::UtxoProvider.configure(utxo_pool_size: 2000) }

      it { expect { subject }.not_to raise_error }
    end

    context 'invalid configuration' do
      before { Glueby::UtxoProvider.configure(utxo_pool_size: 2001) }

      it { expect { subject }.to raise_error(Glueby::Configuration::Errors::InvalidConfiguration) }
    end
  end
end
