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

  describe '#fill_inputs' do
    subject do
      provider.fill_inputs(
        tx,
        target_amount: target_amount,
        current_amount: current_amount,
        fee_estimator: fee_estimator
      )
    end

    let(:tx) do
      tx = Tapyrus::Tx.new
      tx.outputs << Tapyrus::TxOut.new(value: 1_000, script_pubkey: Tapyrus::Script.to_p2pkh(Tapyrus::Key.generate.hash160))
      tx
    end
    let(:target_amount) { 1_000 }
    let(:current_amount) { 0 }

    context 'use FeeEstimator::Auto' do
      let(:fee_estimator) { Glueby::Contract::FeeEstimator::Auto.new }

      context 'the tx has no inputs' do
        let(:utxos) do
          [
            { txid: "33a87aa53268376862076180bad5aa0542373dfde22d4b4d62dd7016c16fd5a2", vout: 0, amount: 2_000 },
            { txid: "33a87aa53268376862076180bad5aa0542373dfde22d4b4d62dd7016c16fd5a2", vout: 1, amount: 1_000 },
            { txid: "33a87aa53268376862076180bad5aa0542373dfde22d4b4d62dd7016c16fd5a2", vout: 2, amount: 1_000 }
          ]
        end

        it 'adds inputs UTXOs which amount is Gleuby::UtxoProvider::DEFAULT_VALUE = 1_000' do
          allow(provider.wallet).to receive(:list_unspent).once.and_return(utxos)
          tx, fee, current_amount, provided_utxos = subject
          expect(tx.inputs.size).to eq(2)
          expect(fee).to eq(360)
          expect(current_amount).to eq(2_000)
          expect(provided_utxos).to contain_exactly(*utxos[1..2])
        end
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

      it 'cache value' do
        allow(Glueby::AR::SystemInformation).to receive(:utxo_provider_default_value).and_return(3_000)
        expect(subject).to eq 3_000
        expect(subject).to eq 3_000
        expect(Glueby::AR::SystemInformation).to have_received(:utxo_provider_default_value).once
      end
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

      it 'cache value' do
        allow(Glueby::AR::SystemInformation).to receive(:utxo_provider_pool_size).and_return(300)
        expect(subject).to eq 300
        expect(subject).to eq 300
        expect(Glueby::AR::SystemInformation).to have_received(:utxo_provider_pool_size).once
      end
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

  describe '#tpc_amount' do
    subject { provider.tpc_amount }

    let(:key) do
      wallet = Glueby::Internal::Wallet::AR::Wallet.find_by(wallet_id: provider.wallet.id)
      wallet.keys.create(purpose: :receive)
    end

    before do
      Glueby::UtxoProvider.configure(utxo_pool_size: 2000)
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        index: 0,
        script_pubkey: '76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
        key: key,
        value: 2_000,
        status: :finalized
      )
    end

    it { expect(subject).to eq(2_000) }
  end

  describe '#current_utxo_pool_size' do
    subject { provider.current_utxo_pool_size }

    let(:pool_outputs) do
      10.times.map do |i|
        {
          txid: 'f14b29639483da7c8d17b7b7515da4ff78b91b4b89434e7988ab1bc21ab41377',
          vout: i,
          script_pubkey: '21c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016bc76a914fc688c091d91789ccda7a27bd8d88be9ae4af58e88ac',
          amount: 1_000,
          finalized: true
        }
      end
    end

    let(:unspents) do
      [{
         txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
         script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
         vout: 0,
         amount: 100_000_000,
         finalized: true
       }] + pool_outputs
    end

    before do
      allow(Glueby::Internal::Wallet).to receive(:load).and_return(wallet)
      allow(wallet).to receive(:list_unspent).and_return(unspents)
    end

    it { expect(subject).to eq(10) }
  end

  describe '#address' do
    subject { provider.address }

    let(:address) do
      wallet = Glueby::Internal::Wallet::AR::Wallet.find_by(wallet_id: provider.wallet.id)
      wallet.keys.map(&:address).first
    end

    it { expect(subject).to eq(address) }
  end
end
