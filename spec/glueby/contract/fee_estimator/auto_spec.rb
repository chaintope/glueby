RSpec.describe 'Glueby::Contract::FeeEstimator::Calc' do
  describe '#fee' do
    subject { Glueby::Contract::FeeEstimator::Auto.new.fee(tx) }

    let(:tx) { double('tx', to_payload: "\x00" * bytesize) }
    let(:bytesize) { 219 }

    it { is_expected.to eq 219 }
    it { is_expected.to be_a(Integer) }

    context 'if specify fee_rate' do
      subject { Glueby::Contract::FeeEstimator::Auto.new(fee_rate: 100).fee(tx) }

      it { is_expected.to eq 22 }
    end

    context 'default_fee_rate is specified' do
      before do
        Glueby::Contract::FeeEstimator::Auto.default_fee_rate = 600
      end

      after do
        Glueby::Contract::FeeEstimator::Fixed.default_fixed_fee = nil
      end

      it { is_expected.to eq 132 }
    end
  end
end
