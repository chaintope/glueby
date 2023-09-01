require_relative '../../../support/contract_builder_test_support'

RSpec.describe Glueby::Internal::ContractBuilder, active_record: true do
  describe '#auto_fulfill_inputs' do
    let(:instance) do
      described_class.new(
        sender_wallet: sender_wallet,
        fee_estimator: fee_estimator,
        use_auto_fulfill_inputs: true,
        use_unfinalized_utxo: use_unfinalized_utxo
      )
    end
    let(:sender_wallet) { Glueby::Internal::Wallet.create }
    let(:use_unfinalized_utxo) { false }

    let(:valid_script_pubkey_hex) { '76a914ec88ce760de37265b11f48ee341248aab42615fb88ac' }
    let(:valid_script_pubkey) { Tapyrus::Script.parse_from_payload(valid_script_pubkey_hex.htb) }
    let(:valid_reissuable_color_id) { Tapyrus::Color::ColorIdentifier.reissuable(valid_script_pubkey) }
    let(:valid_address) { '17yRw6s6t5GWWJmDiqMm49Krsa8oPy96tx' }

    before do
      Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new
    end

    subject { instance.build }

    RSpec::Matchers.define :has_unique_inputs do
      match do |tx|
        tx.inputs.map { |i| i.out_point.txid + i.out_point.index.to_s }.uniq.size == tx.inputs.size
      end

      failure_message do |actual|
        'expected that the tx has unique inputs but it has duplicated ' \
        "inputs: #{actual.inputs.map { |i| i.out_point.to_payload.bth }}"
      end

      failure_message_when_negated do |actual|
        'expected that the tx has duplicate inputs but it has unique ' \
        "inputs: #{actual.inputs.map { |i| i.out_point.to_payload.bth }}"
      end
    end

    shared_examples 'it has enough inputs' do
      context 'fee is 0' do
        let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new(fixed_fee: 0) }

        context 'it needs 3000 tapyrus' do
          before do
            instance.pay(valid_address, 3000)
          end

          it 'fulfill inputs from sender\'s wallet' do
            expect { subject }.not_to raise_error
            expect(subject.inputs.size).to eq(3)
            expect(subject).to has_unique_inputs
          end
        end

        context 'it needs 1100 tapyrus' do
          before do
            instance.pay(valid_address, 1100)
          end

          it 'fulfill inputs from sender\'s wallet' do
            expect { subject }.not_to raise_error
            expect(subject.inputs.size).to eq(2)
            expect(subject).to has_unique_inputs
          end
        end

        context 'it needs 1100 colored coins' do
          before do
            instance.pay(valid_address, 1100, valid_reissuable_color_id)
                    .change_address(valid_address, valid_reissuable_color_id)
          end

          it 'fulfill inputs from sender\'s wallet' do
            expect { subject }.not_to raise_error
            expect(subject.inputs.size).to eq(2)
            expect(subject).to has_unique_inputs
          end
        end

        context 'it needs 3000 colored coins' do
          before do
            instance.pay(valid_address, 3000, valid_reissuable_color_id)
          end

          it 'fulfill inputs from sender\'s wallet' do
            expect { subject }.not_to raise_error
            expect(subject.inputs.size).to eq(3)
            expect(subject).to has_unique_inputs
          end
        end
      end

      context 'fee is 1000' do
        let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new(fixed_fee: 1000) }

        context 'it needs 4000 tapyrus' do
          before do
            instance.pay(valid_address, 3000)
          end

          it 'fulfill inputs from sender\'s wallet' do
            expect { subject }.not_to raise_error
            expect(subject.inputs.size).to eq(4)
            expect(subject).to has_unique_inputs
          end
        end

        context 'it needs 2100 tapyrus' do
          before do
            instance.pay(valid_address, 1100)
          end

          it 'fulfill inputs from sender\'s wallet' do
            expect { subject }.not_to raise_error
            expect(subject.inputs.size).to eq(3)
            expect(subject).to has_unique_inputs
          end
        end

        context 'it needs 1100 colored coins' do
          before do
            instance.pay(valid_address, 1100, valid_reissuable_color_id)
                    .change_address(valid_address, valid_reissuable_color_id)
          end

          it 'fulfill inputs from sender\'s wallet' do
            expect { subject }.not_to raise_error
            expect(subject.inputs.size).to eq(3)
            expect(subject).to has_unique_inputs
          end
        end

        context 'it needs 3000 colored coins' do
          before do
            instance.pay(valid_address, 3000, valid_reissuable_color_id)
          end

          it 'fulfill inputs from sender\'s wallet' do
            expect { subject }.not_to raise_error
            expect(subject.inputs.size).to eq(4)
            expect(subject).to has_unique_inputs
          end
        end
      end
    end

    context 'UtxoProvider is disabled' do
      before do
        # Here should funds UTXOs from sender's wallet
        fund_to_wallet(sender_wallet, count: 4)
        fund_to_wallet(sender_wallet, color_id: valid_reissuable_color_id, count: 4)
      end
      it_behaves_like 'it has enough inputs'
    end

    context 'UtxoProvider is enabled' do
      before do
        Glueby.configuration.enable_utxo_provider!

        # Here should funds tapyrus UTXOs from UtxoProvider and colored coins UTXOs from sender's wallet
        fund_to_wallet(Glueby::UtxoProvider.new.wallet, count: 4)
        fund_to_wallet(sender_wallet, color_id: valid_reissuable_color_id, count: 4)
      end

      after do
        Glueby.configuration.disable_utxo_provider!
      end

      it_behaves_like 'it has enough inputs'
    end
  end
end