require 'rspec'

RSpec.describe 'Glueby::Contract::FeeEstimator' do
  describe '#dummy_tx' do
    subject { Glueby::Contract::FeeEstimator.dummy_tx(Tapyrus::Tx.new) }

    it { expect(subject.inputs.size).to eq 1 }
    it { expect(subject.outputs.size).to eq 1 }
  end
end
