require 'active_record'
require 'rake'

RSpec.describe 'Glueby::Contract::Task::WalletAdapter', active_record: true  do
  before(:each) do
    setup_mock
  end

  setup_responses

  describe '#import_block' do
    subject { Rake.application['glueby:contract:wallet_adapter:import_block'].invoke('022890167018b090211fb8ef26970c26a0cac6d29e5352f506dc31bbb84f3ce7') }

    after { Rake.application['glueby:contract:wallet_adapter:import_block'].reenable }

    it do
      expect(rpc).to receive(:getblock).once
      expect(rpc).to receive(:getrawtransaction).twice
      subject
      expect(Glueby::Internal::Wallet::AR::Utxo::find_by(txid: 'd176b97d76488de0a85609c359eba1ceb357e739c334aa93ed16eff1fd86c06e', index: 0)).to be_nil
      expect(Glueby::Internal::Wallet::AR::Utxo::find_by(txid: 'b4d0dbafa6777d8a902cf4359bdf1bdca3dbaca9ad450f284530cf039f49a23b', index: 0)).not_to be_nil
    end
    it { expect { subject }.to change { Glueby::Internal::Wallet::AR::Utxo.count }.from(1).to(2) }
  end

  describe '#import_tx' do
    subject { Rake.application['glueby:contract:wallet_adapter:import_tx'].invoke('b4d0dbafa6777d8a902cf4359bdf1bdca3dbaca9ad450f284530cf039f49a23b') }

    after { Rake.application['glueby:contract:wallet_adapter:import_tx'].reenable }

    it do
      expect(rpc).to receive(:getrawtransaction).once
      subject
      expect(Glueby::Internal::Wallet::AR::Utxo::find_by(txid: 'd176b97d76488de0a85609c359eba1ceb357e739c334aa93ed16eff1fd86c06e', index: 0)).to be_nil
      expect(Glueby::Internal::Wallet::AR::Utxo::find_by(txid: 'b4d0dbafa6777d8a902cf4359bdf1bdca3dbaca9ad450f284530cf039f49a23b', index: 0)).not_to be_nil
    end
    it { expect { subject }.not_to change { Glueby::Internal::Wallet::AR::Utxo.count } }

    context 'if tx is not associated with glueby wallet' do
      let(:private_key) { '22f774bbcf6a39b3dbeb47761b4d83b5cb0c6cf558db7c400ddd2bbe19cc3e79' }

      it { expect { subject }.to change { Glueby::Internal::Wallet::AR::Utxo.count }.from(1).to(0) }
    end
  end

end
