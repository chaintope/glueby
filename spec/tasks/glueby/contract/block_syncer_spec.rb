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
    subject { Rake.application['glueby:contract:block_syncer:start'] }

    it do
      expect(rpc).to receive(:getblockcount).once
      expect(rpc).to receive(:getblock).twice
      expect(rpc).to receive(:getblockhash).twice
      expect(rpc).to receive(:getrawtransaction).exactly(4).times
      expect(Glueby::AR::SystemInformation.synced_block_height.info_value.to_i).to eq(1)
      expect(Glueby::Internal::Wallet::AR::Utxo.count).to eq(1)
      subject.invoke
      expect(Glueby::AR::SystemInformation.synced_block_height.info_value.to_i).to eq(2)
      expect(Glueby::Internal::Wallet::AR::Utxo.count).to eq(2)
    end
  end

end