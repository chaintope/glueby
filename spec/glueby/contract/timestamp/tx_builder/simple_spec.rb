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
          expect(builder.instance_variable_get('@txb')).to receive(:add_utxo_to!)
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
            expect(builder.instance_variable_get('@txb')).not_to receive(:add_utxo_to!)
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
            expect(builder.instance_variable_get('@txb')).not_to receive(:add_utxo_to!)
            expect(builder.instance_variable_get('@wallet')).not_to receive(:internal_wallet)
            subject
          end
        end
      end
    end
  end

  describe '#build' do
    let(:wallet) { TestWallet.new(internal_wallet) }
    let(:internal_wallet) { TestInternalWallet.new }
    let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new }
    let(:prefix) { 'prefix' }
    let(:content) { 'content' }
    let(:builder) do
      Glueby::Contract::Timestamp::TxBuilder::Simple
        .new(wallet, fee_estimator)
        .set_inputs(nil)
        .set_data(prefix, content)
    end
    let(:unspents) do
      2.times.map do |i|
        {
          txid: '1d49c8038943d37c2723c9c7a1c4ea5c3738a9bad5827ddc41e144ba6aef36db',
          script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
          vout: i,
          amount: 50_000_000,
          finalized: true
        }
      end
    end

    before do
      allow(Glueby::Wallet).to receive(:load).and_return(wallet)
      allow(internal_wallet).to receive(:list_unspent).and_return(unspents)
    end

    context 'it gets a prefix that has a single hexadecimal digit' do
      let(:prefix) { 'prefix' }

      it 'set correct OP_RETURN data' do
        tx = builder.build
        expect(tx.outputs.first.script_pubkey.op_return_data.bth).to eq('70726566697801636f6e74656e74')
      end
    end

    context 'it gets a content that has a single hexadecimal digit' do
      let(:content) { 'content' }

      it 'set correct OP_RETURN data' do
        tx = builder.build
        expect(tx.outputs.first.script_pubkey.op_return_data.bth).to eq('707265666978636f6e74656e7401')
      end
    end

    context 'prefix and contents are hex string' do
      let(:prefix) { '707265666978' }
      let(:content) { 'ed7002b439e9ac845f22357d822bac1444730fbdb6016d3ec9432297b9ec9f73' }

      it 'set correct OP_RETURN data' do
        tx = builder.build
        expect(tx.outputs.first.script_pubkey.op_return_data.bth).to eq('37303732363536363639373865643730303262343339653961633834356632323335376438323262616331343434373330666264623630313664336563393433323239376239656339663733')
      end
    end

    context 'prefix and contents are bytes stream' do
      let(:prefix) { '707265666978'.htb }
      let(:content) { 'ed7002b439e9ac845f22357d822bac1444730fbdb6016d3ec9432297b9ec9f73'.htb }

      it 'set correct OP_RETURN data' do
        tx = builder.build
        expect(tx.outputs.first.script_pubkey.op_return_data.bth).to eq('707265666978ed7002b439e9ac845f22357d822bac1444730fbdb6016d3ec9432297b9ec9f73')
      end
    end

    context 'prefix and contents contain multi bytes characters' do
      let(:prefix) { 'プレフィックス' }
      let(:content) { 'コンテンツ' }

      it 'set correct OP_RETURN data' do
        tx = builder.build
        expect(tx.outputs.first.script_pubkey.op_return_data.bth).to eq('e38397e383ace38395e382a3e38383e382afe382b9e382b3e383b3e38386e383b3e38384')
      end
    end
  end
end