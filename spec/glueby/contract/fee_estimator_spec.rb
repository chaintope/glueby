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

  describe '#fee' do
    subject { estimator.fee(tx) }

    class Estimator
      include Glueby::Contract::FeeEstimator
    end

    let(:estimator) { Estimator.new }
    let(:tx) { Tapyrus::Tx.new }

    it "Estimator#fee should be implemented" do
      expect{subject}.to raise_error(NotImplementedError)
    end
  end
end
