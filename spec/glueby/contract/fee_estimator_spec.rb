require 'rspec'

RSpec.describe 'Glueby::Contract::FeeEstimator' do
  describe '#dummy_tx' do
    subject { Glueby::Contract::FeeEstimator.dummy_tx(Tapyrus::Tx.new) }

    it { expect(subject.inputs.size).to eq 1 }
    it { expect(subject.outputs.size).to eq 1 }

    describe 'dummy_input_count: option' do
      subject { Glueby::Contract::FeeEstimator.dummy_tx(Tapyrus::Tx.new, dummy_input_count: 2) }

      it { expect(subject.inputs.size).to eq 2 }
    end
  end
end
