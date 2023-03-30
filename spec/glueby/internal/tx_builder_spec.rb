RSpec.describe Glueby::Internal::TxBuilder do
  let(:instance) do
    described_class.new(
      signer_wallet: signer_wallet,
      fee_estimator: fee_estimator,
      use_auto_fee: use_auto_fee,
      use_auto_fulfill_inputs: use_auto_fulfill_inputs,
      use_unfinalized_utxo: use_unfinalized_utxo
    )
  end
  let(:signer_wallet) { instance_double(Glueby::Internal::Wallet) }
  let(:fee_estimator) { instance_double(Glueby::Contract::FeeEstimator::Fixed) }
  let(:use_auto_fee) { false }
  let(:use_auto_fulfill_inputs) { false }
  let(:use_unfinalized_utxo) { false }

  shared_examples_for 'splitable' do
    context 'split is 1' do
      let(:split) { 1 }

      it 'increase outgoing amount and one output' do
        expect { subject }
          .to change { instance.instance_variable_get('@outgoings')[color_id] }.from(nil).to(1000)
          .and change { instance.outputs.size }.from(0).to(1)
      end
    end

    context 'split is 9' do
      let(:split) { 9 }

      it 'increase outgoing amount and one output' do
        expect { subject }
          .to change { instance.instance_variable_get('@outgoings')[color_id] }.from(nil).to(1000)
          .and change { instance.outputs.size }.from(0).to(9)
        expect(instance.outputs.map(&:value)).to eq([111, 111, 111, 111, 111, 111, 111, 111, 112])
      end
    end

    context 'split is 10' do
      let(:split) { 10 }

      it 'increase outgoing amount and one output' do
        expect { subject }
          .to change { instance.instance_variable_get('@outgoings')[color_id] }.from(nil).to(1000)
          .and change { instance.outputs.size }.from(0).to(10)
        expect(instance.outputs.map(&:value)).to eq([100, 100, 100, 100, 100, 100, 100, 100, 100, 100])
      end
    end
  end

  describe '#reissuable_split' do
    subject { instance.reissuable_split(script_pubkey, address, value, split) }

    let(:script_pubkey) { Tapyrus::Script.parse_from_payload('76a914ec88ce760de37265b11f48ee341248aab42615fb88ac'.htb) }
    let(:address) { '17yRw6s6t5GWWJmDiqMm49Krsa8oPy96tx' }
    let(:color_id) { Tapyrus::Color::ColorIdentifier.reissuable(script_pubkey) }
    let(:value) { 1000 }
    let(:split) { 1 }

    it_behaves_like 'splitable'
  end

  describe '#non_reissuable_split' do
    subject { instance.non_reissuable_split(out_point, address, value, split) }

    let(:out_point) { Tapyrus::OutPoint.new('0000000000000000000000000000000000000000000000000000000000000000', 0) }
    let(:address) { '17yRw6s6t5GWWJmDiqMm49Krsa8oPy96tx' }
    let(:color_id) { Tapyrus::Color::ColorIdentifier.non_reissuable(out_point) }
    let(:value) { 1000 }
    let(:split) { 1 }

    it_behaves_like 'splitable'
  end
end