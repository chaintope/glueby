# frozen_string_literal: true

RSpec.describe 'glueby:utxo_provider', active_record: true do
  describe "#manage_utxo_prool" do
    subject { Rake.application['glueby:utxo_provider:manage_utxo_pool'].invoke }

    let(:instance) { instance_double("utxo_provider") }

    it 'execute UtxoProvider::Tasks#manage_utxo_pool' do
      allow(Glueby::UtxoProvider::Tasks).to receive(:new).and_return(instance)
      allow(instance).to receive(:manage_utxo_pool)
      subject
      expect(instance).to have_received(:manage_utxo_pool).once
    end
  end

  describe "#status" do
    subject { Rake.application['glueby:utxo_provider:status'].invoke }

    it 'show status' do
      expect { subject }.to output(/Status: Not Ready\n/).to_stdout
    end
  end

  describe "#address" do
    subject { Rake.application['glueby:utxo_provider:address'].invoke }

    let(:instance) { instance_double("utxo_provider") }

    it 'show address' do
      allow(Glueby::UtxoProvider).to receive(:new).and_return(instance)
      allow(instance).to receive(:address).and_return("1DBgMCNBdjQ1Ntz1vpwx2HMYJmc9kw88iT")
      expect { subject }.to output("1DBgMCNBdjQ1Ntz1vpwx2HMYJmc9kw88iT\n").to_stdout
    end
  end
end
