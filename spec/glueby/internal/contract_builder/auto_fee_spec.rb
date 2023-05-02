require_relative '../../../support/contract_builder_test_support'

RSpec.describe Glueby::Internal::ContractBuilder, active_record: true do
  describe 'auto fee feature' do
    let(:instance) do
      described_class.new(
        sender_wallet: sender_wallet,
        fee_estimator: fee_estimator,
        use_auto_fee: true,
        use_auto_fulfill_inputs: use_auto_fulfill_inputs,
        use_unfinalized_utxo: use_unfinalized_utxo
      )
    end
    let(:sender_wallet) { Glueby::Internal::Wallet.create }
    let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new }
    let(:use_auto_fulfill_inputs) { false }
    let(:use_unfinalized_utxo) { false }

    let(:valid_script_pubkey_hex) { valid_script_pubkey.to_hex }
    let(:valid_script_pubkey) { Tapyrus::Script.parse_from_addr(sender_wallet.change_address) }
    let(:valid_reissuable_color_id) { Tapyrus::Color::ColorIdentifier.reissuable(valid_script_pubkey) }
    let(:valid_address) { '17yRw6s6t5GWWJmDiqMm49Krsa8oPy96tx' }

    before do
      Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new
    end

    subject { instance.build }

    context 'UtxoProvider is disabled' do
      before do
        fund_to_wallet(sender_wallet)
      end

      context 'fee_estimator is auto' do
        let(:fee_estimator) { Glueby::Contract::FeeEstimator::Auto.new }

        context 'input amount is enough to pay fee and outgoing value' do
          before do
            instance.pay(valid_address, 600)
                    .add_utxo({
                      txid: 'a' * 64,
                      vout: 0,
                      amount: 2600,
                      script_pubkey: valid_script_pubkey_hex
                    })
          end

          it 'just add a input for fee and a change output' do
            expect { subject }.not_to raise_error
            # It have 2 inputs, 1 by #add_utxo and 1 by #auto_fee_with_sender_wallet
            # FIXME: But, the input by #auto_fee_with_sender_wallet is unnecessary because the input by #add_utxo is enough to pay fee.
            expect(subject.inputs.size).to eq(2)
            expect(subject.outputs.size).to eq(2)
            expect(fee_estimator.fee(subject)).to eq(219)
            # input amount is 2600, outgoing value is 600, fee is 219, so change is 1781
            expect(subject.outputs[1].value).to eq(1781)
          end
        end

        context 'change amount is less than dust threshold to the change output' do
          before do
            instance.pay(valid_address, 600)
                    .add_utxo({
                      txid: 'a' * 64,
                      vout: 0,
                      amount: 1_000,
                      script_pubkey: valid_script_pubkey_hex
                    })
          end

          it 'doesn\'t add a change output' do
            # input amount is 1000, outgoing value is 600, fee is 185, change will be 215, but the change amount is
            # less than dust threshold 546.
            expect { subject }.not_to raise_error
            expect(subject.inputs.size).to eq(1)
            expect(subject.outputs.size).to eq(1)
            expect(subject.outputs[0].value).to eq(600)
            expect(fee_estimator.fee(subject)).to eq(185)
          end
        end

        context 'input amount is insufficient to pay fee' do
          before do
            instance.pay(valid_address, 600)
                    .add_utxo({
                      txid: 'a' * 64,
                      vout: 0,
                      amount: 600,
                      script_pubkey: valid_script_pubkey_hex
                    })
          end

          it 'UtxoProvider add 1 input' do
            expect { subject }.not_to raise_error
            expect(subject.outputs.size).to eq(2)
            expect(subject.outputs[0].value).to eq(600)
            expect(fee_estimator.fee(subject)).to eq(360)
            # input amount is 1600, outgoing value is 600, fee is 360, so change is 640.
            expect(subject.outputs[1].value).to eq(640)
          end
        end
      end

      context 'fee_estimator is fixed' do
        let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new(fixed_fee: 1_000) }

        context 'input amount is enough to pay fee and outgoing value' do
          before do
            instance.pay(valid_address, 600)
                    .add_utxo({
                      txid: 'a' * 64,
                      vout: 0,
                      amount: 2600,
                      script_pubkey: valid_script_pubkey_hex
                    })
          end

          it 'just add a input for fee and a change output' do
            expect { subject }.not_to raise_error
            expect(subject.inputs.size).to eq(1)
            expect(subject.outputs.size).to eq(2)
            # input amount is 2600, outgoing value is 600, fee is 1000, so change is 1000
            expect(subject.outputs[1].value).to eq(1_000)
          end
        end

        context 'change amount is less than dust threshold to the change output' do
          before do
            instance.pay(valid_address, 600)
                    .add_utxo({
                      txid: 'a' * 64,
                      vout: 0,
                      amount: 2_000,
                      script_pubkey: valid_script_pubkey_hex
                    })
          end

          it 'doesn\'t add a change output' do
            # input amount is 2000, outgoing value is 600, fee is 1000, so change is 400.
            # But the change value is less than dust threshold 546. So the change output won't add.
            expect { subject }.not_to raise_error
            expect(subject.inputs.size).to eq(1)
            expect(subject.outputs.size).to eq(1)
            expect(subject.outputs[0].value).to eq(600)
          end
        end

        context 'input amount is insufficient to pay fee' do
          before do
            instance.pay(valid_address, 600)
                    .add_utxo({
                      txid: 'a' * 64,
                      vout: 0,
                      amount: 1500,
                      script_pubkey: valid_script_pubkey_hex
                    })
          end

          it 'UtxoProvider add 1 input' do
            expect { subject }.not_to raise_error
            expect(subject.outputs.size).to eq(2)
            expect(subject.outputs[0].value).to eq(600)
            # input amount is 2500, outgoing value is 600, fee is 1000, so change is 900.
            expect(subject.outputs[1].value).to eq(900)
          end
        end
      end
    end

    context 'UtxoProvider is enabled' do
      before do
        Glueby.configuration.enable_utxo_provider!
        fund_to_wallet(Glueby::UtxoProvider.instance.wallet)
      end

      after do
        Glueby.configuration.disable_utxo_provider!
      end

      context 'fee_estimator is auto' do
        let(:fee_estimator) { Glueby::Contract::FeeEstimator::Auto.new }

        context 'input amount is enough to pay fee and outgoing value' do
          before do
            instance.pay(valid_address, 1_000)
                    .add_utxo({
                      txid: 'a' * 64,
                      vout: 0,
                      amount: 2_600,
                      script_pubkey: valid_script_pubkey_hex
                    })
          end

          it 'just add a change output' do
            expect { subject }.not_to raise_error
            expect(subject.inputs.size).to eq(1)
            expect(subject.outputs.size).to eq(2)
            expect(fee_estimator.fee(subject)).to eq(219)
            # input amount is 2600, outgoing value is 1000, fee is 219, so change is 1381
            expect(subject.outputs[1].value).to eq(1381)
          end
        end

        context 'change amount is less than dust threshold' do
          before do
            instance.pay(valid_address, 600)
                    .add_utxo({
                      txid: 'a' * 64,
                      vout: 0,
                      amount: 1_000,
                      script_pubkey: valid_script_pubkey_hex
                    })
          end

          it 'doesn\'t add change output' do
            expect { subject }.not_to raise_error
            expect(subject.inputs.size).to eq(1)
            # input amount is 1000, outgoing value is 600, fee is 185, so change is 215.
            # but the change amount is less than dust threshold 546, so it doesn't add change output.
            expect(subject.outputs.size).to eq(1)
            expect(fee_estimator.fee(subject)).to eq(185)
            expect(subject.outputs[0].value).to eq(600)
          end
        end

        context 'input amount is insufficient to pay fee' do
          before do
            instance.pay(valid_address, 600)
                    .add_utxo({
                      txid: 'a' * 64,
                      vout: 0,
                      amount: 600,
                      script_pubkey: valid_script_pubkey_hex
                    })
          end

          it 'UtxoProvider add 1 input' do
            expect { subject }.not_to raise_error
            expect(subject.inputs.size).to eq(2)
            expect(subject.outputs.size).to eq(2)
            expect(subject.outputs[0].value).to eq(600)
            expect(fee_estimator.fee(subject)).to eq(360)
            # input amount is 1600, outgoing value is 600, fee is 360, so change is 640.
            expect(subject.outputs[1].value).to eq(640)
          end
        end
      end

      context 'fee_estimator is fixed' do
        let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new(fixed_fee: 1_000) }

        context 'input amount is enough to pay fee and outgoing value' do
          before do
            instance.pay(valid_address, 1_000)
                    .add_utxo({
                      txid: 'a' * 64,
                      vout: 0,
                      amount: 2_600,
                      script_pubkey: valid_script_pubkey_hex
                    })
          end

          it 'just add a change output' do
            expect { subject }.not_to raise_error
            expect(subject.inputs.size).to eq(1)
            expect(subject.outputs.size).to eq(2)
            # input amount is 2600, outgoing value is 1000, fee is 1000, so change is 600
            expect(subject.outputs[1].value).to eq(600)
          end
        end

        context 'change amount is less than dust threshold' do
          before do
            instance.pay(valid_address, 600)
                    .add_utxo({
                      txid: 'a' * 64,
                      vout: 0,
                      amount: 2_000,
                      script_pubkey: valid_script_pubkey_hex
                    })
          end

          it 'doesn\'t add change output' do
            expect { subject }.not_to raise_error
            expect(subject.inputs.size).to eq(1)
            # input amount is 2000, outgoing value is 600, fee is 1000, so change is 400.
            # but the change amount is less than dust threshold 546, so it doesn't add change output.
            expect(subject.outputs.size).to eq(1)
            expect(subject.outputs[0].value).to eq(600)
          end
        end

        context 'input amount is insufficient to pay fee' do
          before do
            instance.pay(valid_address, 600)
                    .add_utxo({
                      txid: 'a' * 64,
                      vout: 0,
                      amount: 1500,
                      script_pubkey: valid_script_pubkey_hex
                    })
          end

          it 'UtxoProvider add 1 input' do
            expect { subject }.not_to raise_error
            expect(subject.outputs.size).to eq(2)
            expect(subject.outputs[0].value).to eq(600)
            # input amount is 2500, outgoing value is 600, fee is 1000, so change is 900.
            expect(subject.outputs[1].value).to eq(900)
          end
        end
      end
    end
  end
end
