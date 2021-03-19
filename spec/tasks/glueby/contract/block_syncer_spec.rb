require 'active_record'
require 'rake'

RSpec.describe 'Glueby::Contract::Task::BlockSyncer', active_record: true do

  before(:each) do
    setup_mock
  end

  setup_responses


  describe '#start' do
    subject { Rake.application['glueby:contract:block_syncer:start'].execute }

    it do
      expect(rpc).to receive(:getblockcount).once
      expect(rpc).to receive(:getblock).once
      expect(rpc).to receive(:getblockhash).once
      expect(rpc).to receive(:getrawtransaction).twice
      subject
      expect(Glueby::Internal::Wallet::AR::SystemInformation.find(1)).not_to be_nil
    end
    
    it { expect { subject }.to change { Glueby::Internal::Wallet::AR::Utxo.count }.from(1).to(2) }
  end

end