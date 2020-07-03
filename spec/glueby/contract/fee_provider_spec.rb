RSpec.describe 'Glueby::Contract::FeeProvider' do
  describe 'FixedFeeProvider' do
    let(:tx) { Tapyrus::Tx.new }

    describe '#fee' do
      subject { Glueby::Contract::FixedFeeProvider.new.fee(tx) }

      it { is_expected.to eq 10_000 }

      context 'if specify fixed fee' do
        subject { Glueby::Contract::FixedFeeProvider.new(fixed_fee: 100).fee(tx) }

        it { is_expected.to eq 100 }
      end
    end
  end
end
