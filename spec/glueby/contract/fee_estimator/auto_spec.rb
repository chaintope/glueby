RSpec.describe 'Glueby::Contract::FeeEstimator::Auto' do
  describe '#fee' do
    subject { Glueby::Contract::FeeEstimator::Auto.new.fee(tx) }

    let(:tx) do
      double(
        'tx',
        size: bytesize,
        outputs: outputs
      )
    end
    let(:bytesize) { 219 }
    let(:outputs) { [] }

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
        Glueby::Contract::FeeEstimator::Auto.default_fee_rate = nil
      end

      it { is_expected.to eq 132 }
    end

    context 'The tx has a colored outputs' do
      let(:outputs) { [Tapyrus::TxOut.new(value: 1, script_pubkey: Tapyrus::Script.to_cp2pkh(color_id, pubkey_hash))] }
      let(:color_id) { Tapyrus::Color::ColorIdentifier.parse_from_payload('c102a8574e6631631c1899ec6d2f695b3824de949e664b206b43cdd41d8b1c1ba7'.htb) }
      let(:pubkey_hash) { '5f99099e8f99e2f3eec66c46d2c380639b04b033' }

      it { is_expected.to eq 220 }
      it { is_expected.to be_a(Integer) }
    end
  end
end
