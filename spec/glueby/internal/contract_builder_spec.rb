require_relative '../../support/contract_builder_test_support'

RSpec.describe Glueby::Internal::ContractBuilder, active_record: true do
  let(:instance) do
    described_class.new(
      sender_wallet: sender_wallet,
      fee_estimator: fee_estimator,
      use_auto_fulfill_inputs: use_auto_fulfill_inputs,
      use_unfinalized_utxo: use_unfinalized_utxo
    )
  end
  let(:sender_wallet) { Glueby::Internal::Wallet.create }
  let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new }
  let(:use_auto_fulfill_inputs) { false }
  let(:use_unfinalized_utxo) { false }

  let(:valid_script_pubkey_hex) { '76a914ec88ce760de37265b11f48ee341248aab42615fb88ac' }
  let(:valid_script_pubkey) { Tapyrus::Script.parse_from_payload(valid_script_pubkey_hex.htb) }
  let(:valid_reissuable_color_id) { Tapyrus::Color::ColorIdentifier.reissuable(valid_script_pubkey) }
  let(:valid_address) { '17yRw6s6t5GWWJmDiqMm49Krsa8oPy96tx' }

  before do
    Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new
  end

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

    context 'split count is bigger than value' do
      let(:split) { 11 }
      let(:value) { 10 }

      it 'split up to value amount' do
        expect { subject }
          .to change { instance.instance_variable_get('@outgoings')[color_id] }.from(nil).to(10)
          .and change { instance.outputs.size }.from(0).to(10)
        expect(instance.outputs.map(&:value)).to eq([1, 1, 1, 1, 1, 1, 1, 1, 1, 1])
      end
    end
  end

  shared_examples_for 'issue' do
    it 'increase @issues value' do
      expect { subject }
        .to change { instance.instance_variable_get('@issues')[color_id] }.from(0).to(value)
        .and change { instance.outputs.size }.from(0).to(1)
    end

    context 'use_auto_fullfill_inputs is true' do
      let(:use_auto_fulfill_inputs) { true }

      before do
        fund_to_wallet(sender_wallet)
      end

      it 'doesn\'t raise Glueby::Contract::Errors::InsufficientTokens error' do
        expect { subject.build }.not_to raise_error
      end
    end
  end

  describe '#reissuable' do
    subject { instance.reissuable(script_pubkey, address, value) }

    let(:value) { 1000 }
    let(:script_pubkey) { valid_script_pubkey }
    let(:address) { valid_address }
    let(:color_id) { valid_reissuable_color_id }

    it_behaves_like 'issue'
  end

  describe '#reissuable_split' do
    subject { instance.reissuable_split(script_pubkey, address, value, split) }

    let(:script_pubkey) { valid_script_pubkey }
    let(:address) { valid_address }
    let(:color_id) { valid_reissuable_color_id }
    let(:value) { 1000 }
    let(:split) { 1 }

    it_behaves_like 'splitable'
  end

  describe '#non_reissuable' do
    subject { instance.non_reissuable(out_point, address, value) }

    let(:out_point) { Tapyrus::OutPoint.new('0000000000000000000000000000000000000000000000000000000000000000', 0) }
    let(:address) { valid_address }
    let(:color_id) { Tapyrus::Color::ColorIdentifier.non_reissuable(out_point) }
    let(:value) { 1000 }

    it_behaves_like 'issue'
  end

  describe '#non_reissuable_split' do
    subject { instance.non_reissuable_split(out_point, address, value, split) }

    let(:out_point) { Tapyrus::OutPoint.new('0000000000000000000000000000000000000000000000000000000000000000', 0) }
    let(:address) { valid_address }
    let(:color_id) { Tapyrus::Color::ColorIdentifier.non_reissuable(out_point) }
    let(:value) { 1000 }
    let(:split) { 1 }

    it_behaves_like 'splitable'
  end

  describe '#nft' do
    subject { instance.nft(out_point, address) }

    let(:out_point) { Tapyrus::OutPoint.new('0000000000000000000000000000000000000000000000000000000000000000', 0) }
    let(:address) { valid_address }
    let(:color_id) { Tapyrus::Color::ColorIdentifier.nft(out_point) }
    let(:value) { 1 }

    it_behaves_like 'issue'
  end

  describe '#burn' do
    subject { instance.burn(value, color_id) }
    let(:value) { 1000 }
    let(:color_id) { Tapyrus::Color::ColorIdentifier.reissuable(valid_script_pubkey) }

    it 'increase outgoing amount but keep the outputs count' do
      expect { subject }
        .to change { instance.instance_variable_get('@outgoings')[color_id] }.from(nil).to(1000)
        .and not_change { instance.outputs.size }
    end

    context 'when the color_id is default' do
      let(:color_id) { Tapyrus::Color::ColorIdentifier.default }

      it 'raise ArgumentError' do
        expect { subject }.to raise_error(Glueby::ArgumentError)
      end
    end
  end

  describe '#add_utxo' do
    subject { instance.add_utxo(utxo) }
    let(:utxo) do
      {
        txid: '0000000000000000000000000000000000000000000000000000000000000000',
        vout: 0,
        amount: 1000,
        script_pubkey: valid_script_pubkey_hex,
        color_id: valid_reissuable_color_id.to_hex
      }
    end

    it 'add utxo to the utxos' do
      expect { subject }.to change { instance.utxos.size }.from(0).to(1)
      expect(instance.utxos.first).to eq({
        txid: '0000000000000000000000000000000000000000000000000000000000000000',
        index: 0,
        value: 1000,
        script_pubkey: valid_script_pubkey,
        color_id: valid_reissuable_color_id
      })
    end
  end

  describe '#add_utxo_to' do
    subject do
      instance.add_utxo_to!(
        address: address,
        amount: amount,
        utxo_provider: utxo_provider,
        only_finalized: only_finalized,
        fee_estimator: fee_estimator
      )
    end

    let(:address) { valid_address }
    let(:amount) { 1000 }
    let(:utxo_provider) { nil }
    let(:only_finalized) { true }
    let(:fee_estimator) { nil }

    shared_examples_for 'correct behavior' do
      it 'broadcast for a tx that has an output to the UTXO and the UTXO is add to the utxos' do
        expect(sender_wallet).to receive(:broadcast) do |tx|
          expect(tx.outputs.first.value).to eq(amount)
          expect(tx.outputs.first.script_pubkey).to eq(Tapyrus::Script.parse_from_addr(address))
          tx
        end
        expect { subject }.to change { instance.utxos.size }.from(0).to(1)
        expect(instance.utxos.first[:value]).to eq(amount)
        expect(instance.utxos.first[:index]).to eq(0)
        expect(instance.utxos.first[:script_pubkey]).to eq(Tapyrus::Script.parse_from_addr(address))
      end
    end

    before do
      fund_to_wallet(sender_wallet)
      fund_to_wallet(Glueby::UtxoProvider.instance.wallet)
      fund_to_wallet(Glueby::FeeProvider.new.wallet)
    end

    context 'FeeProvider is disabled' do
      context 'when Glueby::UtxoProvider is enabled' do
        before do
          Glueby.configuration.enable_utxo_provider!
        end

        after do
          Glueby.configuration.disable_utxo_provider!
        end

        context 'fee_estimator is fixed' do
          let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new }

          it_behaves_like 'correct behavior'
        end

        context 'fee_estimator is auto' do
          let(:fee_estimator) { Glueby::Contract::FeeEstimator::Auto.new }

          it_behaves_like 'correct behavior'
        end
      end

      context 'when Glueby::UtxoProvider is disabled' do
        context 'fee_estimator is fixed' do
          let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new }

          it_behaves_like 'correct behavior'
        end

        context 'fee_estimator is auto' do
          let(:fee_estimator) { Glueby::Contract::FeeEstimator::Auto.new }

          it_behaves_like 'correct behavior'
        end
      end
    end

    context 'FeeProvider is enabled' do
      before do
        Glueby.configuration.fee_provider_bears!
      end

      after do
        Glueby.configuration.disable_fee_provider_bears!
      end

      context 'when Glueby::UtxoProvider is enabled' do
        context 'fee_estimator is fixed' do
          let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new }

          it_behaves_like 'correct behavior'
        end

        context 'fee_estimator is auto' do
          let(:fee_estimator) { Glueby::Contract::FeeEstimator::Auto.new }

          it_behaves_like 'correct behavior'
        end
      end

      context 'when Glueby::UtxoProvider is disabled' do
        context 'fee_estimator is fixed' do
          let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new }

          it_behaves_like 'correct behavior'
        end

        context 'fee_estimator is auto' do
          let(:fee_estimator) { Glueby::Contract::FeeEstimator::Auto.new }

          it_behaves_like 'correct behavior'
        end
      end
    end
  end

  describe '#add_p2c_utxo_to' do
    subject do
      instance.add_p2c_utxo_to!(
        metadata: metadata,
        amount: amount,
        only_finalized: only_finalized,
        fee_estimator: my_fee_estimator
      )
    end

    let(:metadata) { 'metadata' }
    let(:amount) { 1000 }
    let(:only_finalized) { true }
    let(:my_fee_estimator) { nil }
    let(:p2c_address) { '18Kw7CUfBsFFKPBSpTyc6yfRjWgX6qY6kg' }
    let(:payment_base) { '021161713252c023a2e5f24b135aa340f5908aa312eb9f294de83e145ceaec666c' }

    shared_examples_for 'correct behavior' do
      before do
        allow(sender_wallet).to receive(:create_pay_to_contract_address)
                                  .with(metadata)
                                  .and_return([p2c_address, payment_base])
      end

      it 'broadcast for a tx that has an output to the p2c address and the UTXO is add to the @p2c_utxos' do
        expect(sender_wallet).to receive(:broadcast) do |tx|
          expect(tx.outputs.first.value).to eq(amount)
          expect(tx.outputs.first.script_pubkey).to eq(Tapyrus::Script.parse_from_addr(p2c_address))
          tx
        end
        expect { subject }
          .to change { instance.utxos.size }.from(0).to(1)
          .and change { instance.p2c_utxos.size }.from(0).to(1)
        expect(instance.p2c_utxos.first[:amount]).to eq(amount)
        expect(instance.p2c_utxos.first[:vout]).to eq(0)
        expect(instance.p2c_utxos.first[:script_pubkey]).to eq(Tapyrus::Script.parse_from_addr(p2c_address).to_hex)
        expect(instance.p2c_utxos.first[:p2c_address]).to eq(p2c_address)
        expect(instance.p2c_utxos.first[:payment_base]).to eq(payment_base)
        expect(instance.p2c_utxos.first[:metadata]).to eq(metadata)
      end
    end

    before do
      fund_to_wallet(sender_wallet)
    end

    context 'it doesn\'t pass the p2c_address and paymetn_base' do
      it_behaves_like 'correct behavior'
    end

    context 'it pass the p2c_address and paymetn_base' do
      subject do
        instance.add_p2c_utxo_to!(
          metadata: metadata,
          amount: amount,
          only_finalized: only_finalized,
          fee_estimator: my_fee_estimator,
          p2c_address: p2c_address,
          payment_base: payment_base
        )
      end

      it_behaves_like 'correct behavior'
    end
  end
end