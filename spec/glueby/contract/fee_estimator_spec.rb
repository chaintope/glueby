RSpec.describe 'Glueby::Contract::FeeEstimator' do
  describe 'FixedFeeEstimator' do
    let(:tx) { Tapyrus::Tx.new }

    describe '#fee' do
      subject { Glueby::Contract::FixedFeeEstimator.new.fee(tx) }

      it { is_expected.to eq 10_000 }

      context 'if specify fixed fee' do
        subject { Glueby::Contract::FixedFeeEstimator.new(fixed_fee: 100).fee(tx) }

        it { is_expected.to eq 100 }
      end

      context 'default_fixed_fee is specified' do
        before do
          Glueby::Contract::FixedFeeEstimator.default_fixed_fee = 600
        end

        after do
          Glueby::Contract::FixedFeeEstimator.default_fixed_fee = nil
        end

        it { is_expected.to eq 600 }
      end

      context 'if fee_provider_bears! is enable' do
        before do
          Glueby.configuration.fee_provider_bears!
        end

        after do
          Glueby.configuration.disable_fee_provider_bears!
        end

        it { is_expected.to eq 0 }
      end
    end
  end
end
