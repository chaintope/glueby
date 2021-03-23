require 'active_record'

RSpec.shared_context 'Set rpc responses' do
  setup_responses
end

RSpec.describe 'Glueby::Contract::Task::BlockSyncer', active_record: true do

  before(:each) do
    setup_mock
  end

  include_context 'Set rpc responses'

  describe '#start' do
    subject { Rake.application['glueby:contract:block_syncer:start'].execute }

    it do
      expect(rpc).to receive(:getblockcount).once
      expect(rpc).to receive(:getblock).twice
      expect(rpc).to receive(:getblockhash).twice
      expect(rpc).to receive(:getrawtransaction).exactly(4).times
      expect { subject }.to change { Glueby::AR::SystemInformation.synced_block_height }.from(1).to(2)
    end

    it do 
      expect { subject }.to change { Glueby::Internal::Wallet::AR::Utxo.count }.from(1).to(2)
    end
  end

end