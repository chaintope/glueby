RSpec.describe 'Glueby::Contract::FeeEstimator::Fiexed' do
    let(:tx) { Tapyrus::Tx.new }

  describe '#fee' do
    shared_examples 'fine fixed estimator' do
      subject { estimator_class.new.fee(tx) }

      let(:estimator_class) { Glueby::Contract::FeeEstimator::Fixed }

      it { is_expected.to eq 10_000 }

      context 'if specify fixed fee' do
        subject { estimator_class.new(fixed_fee: 100).fee(tx) }

        it { is_expected.to eq 100 }
      end

      context 'default_fixed_fee is specified' do
        before do
          estimator_class.default_fixed_fee = 600
        end

        after do
          estimator_class.default_fixed_fee = nil
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

    it_behaves_like 'fine fixed estimator'

    it_behaves_like 'fine fixed estimator' do
      let(:estimator_class) { Glueby::Contract::FixedFeeEstimator }
    end
  end
end
