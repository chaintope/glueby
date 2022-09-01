RSpec.shared_context 'Set rpc responses' do
  setup_responses
end

RSpec.describe 'glueby:block_syncer', active_record: true do
  before(:each) do
    setup_mock
    Glueby.configuration.wallet_adapter = :activerecord
  end

  include_context 'Set rpc responses'

  describe '#start' do
    subject { Rake.application['glueby:block_syncer:start'] }

    it do
      expect(rpc).to receive(:getblockcount).once
      expect(rpc).to receive(:getblock).twice
      expect(rpc).to receive(:getblockhash).twice
      expect(rpc).to receive(:getrawtransaction).exactly(0).times
      expect(Glueby::AR::SystemInformation.synced_block_height.int_value).to eq(0)
      expect(Glueby::Internal::Wallet::AR::Utxo.count).to eq(1)
      subject.invoke
      expect(Glueby::AR::SystemInformation.synced_block_height.int_value).to eq(2)
      expect(Glueby::Internal::Wallet::AR::Utxo.count).to eq(2)
    end
  end

  describe '#update_height' do
    subject { Rake.application['glueby:block_syncer:update_height'] }

    it do
      expect(rpc).to receive(:getblockcount).once
      expect(rpc).to receive(:getblock).exactly(0).times
      expect(rpc).to receive(:getblockhash).exactly(0).times
      expect(rpc).to receive(:getrawtransaction).exactly(0).times
      expect(Glueby::AR::SystemInformation.synced_block_height.int_value).to eq(0)
      expect(Glueby::Internal::Wallet::AR::Utxo.count).to eq(1)
      subject.invoke
      expect(Glueby::AR::SystemInformation.synced_block_height.int_value).to eq(2)
      expect(Glueby::Internal::Wallet::AR::Utxo.count).to eq(1)
    end
  end
end

RSpec.describe 'glueby:contract:block_syncer', active_record: true do
  before(:each) do
    setup_mock
    Glueby.configuration.wallet_adapter = :activerecord
  end

  include_context 'Set rpc responses'

  describe '#start' do
    subject { Rake.application['glueby:contract:block_syncer:start'] }

    it do
      expect(rpc).to receive(:getblockcount).once
      expect(rpc).to receive(:getblock).twice
      expect(rpc).to receive(:getblockhash).twice
      expect(rpc).to receive(:getrawtransaction).exactly(0).times
      expect(Glueby::AR::SystemInformation.synced_block_height.int_value).to eq(0)
      expect(Glueby::Internal::Wallet::AR::Utxo.count).to eq(1)
      subject.invoke
      expect(Glueby::AR::SystemInformation.synced_block_height.int_value).to eq(2)
      expect(Glueby::Internal::Wallet::AR::Utxo.count).to eq(2)
    end
  end
end