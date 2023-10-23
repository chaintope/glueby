# frozen_string_literal: true

RSpec.describe 'glueby:fee_provider', active_record: true do
  describe "#manage_utxo_prool" do
    subject { Rake.application['glueby:fee_provider:manage_utxo_pool'].invoke }

    let(:instance) { instance_double("fee_provider") }

    it 'execute FeeProvider::Tasks#manage_utxo_pool' do
      allow(Glueby::FeeProvider::Tasks).to receive(:new).and_return(instance)
      allow(instance).to receive(:manage_utxo_pool)
      subject
      expect(instance).to have_received(:manage_utxo_pool).once
    end
  end

  describe "#status" do
    subject { Rake.application['glueby:fee_provider:status'].invoke }

    let(:rpc) { instance_double("rpc") }
    it 'show status' do
      allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)
    
      expect { subject }.to output(/Status: Not Ready\n/).to_stdout
    end
  end

  describe "#address" do
    subject { Rake.application['glueby:fee_provider:address'].invoke }

    let(:instance) { instance_double("fee_provider") }
    let(:wallet) { TestInternalWallet.new }

    it 'show address' do
      allow(Glueby::FeeProvider).to receive(:new).and_return(instance)
      allow(instance).to receive(:wallet).and_return(wallet)
      expect { subject }.to output("1DBgMCNBdjQ1Ntz1vpwx2HMYJmc9kw88iT\n").to_stdout
    end
  end
end
