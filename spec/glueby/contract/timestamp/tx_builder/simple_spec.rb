RSpec.describe 'Glueby::Contract::TimestampTxBuilder::Simple', active_record: true do
  describe '#set_input' do
    context 'use activerecord wallet adapter' do
      before do
        Glueby.configuration.wallet_adapter = :activerecord
      end

      after do
        Glueby::Internal::Wallet.wallet_adapter = nil
      end

      let(:wallet) { Glueby::Wallet.create }
      let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new }
      let(:builder) { Glueby::Contract::Timestamp::TxBuilder::Simple.new(wallet, fee_estimator) }
      let(:utxo_provider) { double('utxo_provider') }

      subject { builder.set_inputs(utxo_provider) }

      context 'when utxo_provider is not nil' do
        it 'adds utxo to builder' do
          expect(builder.instance_variable_get('@txb')).to receive(:add_utxo_to)
          subject
        end
      end

      context 'when utxo_provider is nil' do
        let(:utxo_provider) { nil }
        let(:valid_utxo) do
          {
            txid: '00' * 32,
            vout: 0,
            amount: 100,
            finalized: true,
            script_pubkey: '76a91457dd450aed53d4e35d3555a24ae7dbf3e08a78ec88ac'
          }
        end

        context 'fee provider is disabled' do
          it 'adds utxo to builder' do
            expect(builder.instance_variable_get('@txb')).not_to receive(:add_utxo_to)
            expect(builder.instance_variable_get('@wallet'))
              .to receive_message_chain(:internal_wallet, :collect_uncolored_outputs)
                    .and_return([100, [valid_utxo]])
            expect { subject }.to change { builder.instance_variable_get('@txb').utxos.size }.by(1)
          end
        end

        context 'fee provider is enabled' do
          before do
            Glueby.configuration.fee_provider_bears!
          end

          after do
            Glueby.configuration.disable_fee_provider_bears!
          end

          it 'adds utxo to builder' do
            expect(builder.instance_variable_get('@txb')).not_to receive(:add_utxo_to)
            expect(builder.instance_variable_get('@wallet')).not_to receive(:internal_wallet)
            subject
          end
        end
      end
    end
  end
end