require_relative '../../../support/tx_builder_test_support'

RSpec.describe Glueby::Internal::ContractBuilder, active_record: true do
  describe '#auto_fulfill_inputs' do
    let(:instance) do
      described_class.new(
        sender_wallet: sender_wallet,
        fee_estimator: fee_estimator,
        use_auto_fee: use_auto_fee,
        use_auto_fulfill_inputs: true,
        use_unfinalized_utxo: use_unfinalized_utxo
      )
    end
    let(:sender_wallet) { Glueby::Internal::Wallet.create }
    let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new }
    let(:use_auto_fee) { false }
    let(:use_unfinalized_utxo) { false }

    let(:valid_script_pubkey_hex) { '76a914ec88ce760de37265b11f48ee341248aab42615fb88ac' }
    let(:valid_script_pubkey) { Tapyrus::Script.parse_from_payload(valid_script_pubkey_hex.htb) }
    let(:valid_reissuable_color_id) { Tapyrus::Color::ColorIdentifier.reissuable(valid_script_pubkey) }
    let(:valid_address) { '17yRw6s6t5GWWJmDiqMm49Krsa8oPy96tx' }

    before do
      Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new
    end

    subject { instance.build }

    shared_examples 'it has enough inputs' do
      context 'it needs 3000 tapyrus' do
        before do
          instance.pay(valid_address, 3000)
        end

        it 'fulfill inputs from sender\'s wallet' do
          expect { subject }.not_to raise_error
          expect(subject.inputs.size).to eq(3)
        end
      end

      context 'it needs 1100 tapyrus' do
        before do
          instance.pay(valid_address, 1100)
        end

        it 'fulfill inputs from sender\'s wallet' do
          expect { subject }.not_to raise_error
          expect(subject.inputs.size).to eq(2)
        end
      end

      context 'it needs 1100 colored coins' do
        before do
          instance.pay(valid_address, 1100, valid_reissuable_color_id)
        end

        it 'fulfill inputs from sender\'s wallet' do
          expect { subject }.not_to raise_error
          expect(subject.inputs.size).to eq(2)
        end
      end

      context 'it needs 3000 colored coins' do
        before do
          instance.pay(valid_address, 3000, valid_reissuable_color_id)
        end

        it 'fulfill inputs from sender\'s wallet' do
          expect { subject }.not_to raise_error
          expect(subject.inputs.size).to eq(3)
        end
      end
    end

    context 'UtxoProvider is disabled' do
      before do
        # Here should funds UTXOs from sender's wallet
        fund_to_wallet(sender_wallet)
        fund_to_wallet(sender_wallet, color_id: valid_reissuable_color_id)
      end
      it_behaves_like 'it has enough inputs'
    end

    context 'UtxoProvider is enabled' do
      before do
        Glueby.configuration.enable_utxo_provider!

        # Here should funds tapyrus UTXOs from UtxoProvider and colored coins UTXOs from sender's wallet
        fund_to_wallet(Glueby::UtxoProvider.instance.wallet)
        fund_to_wallet(sender_wallet, color_id: valid_reissuable_color_id)
      end

      after do
        Glueby.configuration.disable_utxo_provider!
      end

      it_behaves_like 'it has enough inputs'
    end
  end
end