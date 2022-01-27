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

    it do
      12.times do |i|
        Glueby::Internal::Wallet::AR::Utxo.create(
          txid: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          index: i,
          script_pubkey: '76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
          key: key,
          value: 1_000,
          status: :finalized
        )
      end
      expect(subject[0].inputs.size).to eq 12
      expect(subject[0].outputs.size).to eq 1
      expect(subject[0].outputs.first.script_pubkey).to eq script_pubkey
      expect(subject[0].outputs.first.value).to eq 2_000
      expect(subject[1]).to eq  0
    end

    context 'does not have enough funds' do
      let(:value) { 2_001 }
      it do
        expect { 
          12.times do |i|
            Glueby::Internal::Wallet::AR::Utxo.create(
              txid: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
              index: i,
              script_pubkey: '76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
              key: key,
              value: 1_000,
              status: :finalized
            )
          end
          subject 
        }.to raise_error(Glueby::Contract::Errors::InsufficientFunds)
      end
    end

    context 'contains funds which value is not default value(1_000)' do
      it 'does not use these funds' do
        expect { 
          20.times do |i|
            Glueby::Internal::Wallet::AR::Utxo.create(
              txid: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
              index: i,
              script_pubkey: '76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
              key: key,
              value: 2_000,
              status: :finalized
            )
          end
          subject 
        }.to raise_error(Glueby::Contract::Errors::InsufficientFunds)
      end
    end
  end

  describe "#default_value" do
    subject { provider.default_value }

    context 'from system_informations table' do
      before do
        Glueby::AR::SystemInformation.create(
          info_key: 'utxo_provider_default_value',
          info_value: '3000'
        )
      end
      it { expect(subject).to eq 3_000 }
    end

    context 'from config setting' do
      before { Glueby::UtxoProvider.configure(default_value: 2_000) }
      after { Glueby::UtxoProvider.configure(nil) }

      it { expect(subject).to eq 2_000 }
    end

    context 'from default value' do
      it { expect(subject).to eq 1_000 }
    end
  end

  describe "#utxo_pool_size" do
    subject { provider.utxo_pool_size }

    context 'from system_informations table' do
      before do
        Glueby::AR::SystemInformation.create(
          info_key: 'utxo_provider_pool_size',
          info_value: '300'
        )
      end

      it { expect(subject).to eq 300 }
    end

    context 'from config setting' do
      before { Glueby::UtxoProvider.configure(utxo_pool_size: 200) }
      after { Glueby::UtxoProvider.configure(nil) }

      it { expect(subject).to eq 200 }
    end

    context 'from default value' do
      it { expect(subject).to eq 20 }
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
