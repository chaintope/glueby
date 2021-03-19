require 'active_record'
require 'rake'

RSpec.describe 'Glueby::Contract::Task::BlockSyncer', active_record: true do
  before(:all) do
    @rake = setup_rake_task
  end

  before(:each) do
    setup_mock
  end

  setup_responses

  def setup_rake_task
    Rake::Application.new.tap do |rake|
      Rake.application = rake
      Rake.application.rake_require 'tasks/glueby/contract/timestamp'
      Rake.application.rake_require 'tasks/glueby/contract/wallet_adapter'
      Rake.application.rake_require 'tasks/glueby/contract/block_syncer'
      Rake::Task.define_task(:environment)
    end
  end

  describe '#start' do
    subject { @rake['glueby:contract:block_syncer:start'].execute }

    it do
      expect(rpc).to receive(:getblockcount).once
      expect(rpc).to receive(:getblockhash).twice
      expect(rpc).to receive(:getblock).twice
      expect(rpc).to receive(:getrawtransaction).exactly(4).times
      subject
      expect(Glueby::Internal::Wallet::AR::SystemInformation.find(1)).not_to be_nil
    end
    
    it { expect { subject }.to change { Glueby::Internal::Wallet::AR::Utxo.count }.from(1).to(2) }
  end

end