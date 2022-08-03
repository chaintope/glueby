RSpec.describe 'Glueby::Contract::Timestamp', active_record: true do
  describe '#initialize' do
    let(:wallet) { TestWallet.new(internal_wallet) }
    let(:internal_wallet) { TestInternalWallet.new }

    context 'if digest unspport' do
      subject do
        Glueby::Contract::Timestamp.new(
          wallet: wallet,
          content: "01",
          prefix: '',
          digest: nil
        )
      end

      it { expect { subject }.to raise_error(Glueby::Contract::Errors::UnsupportedDigestType) }
    end

    context 'with unsupported timestamp type' do
      subject do
        Glueby::Contract::Timestamp.new(
          wallet: wallet,
          content: 'bar',
          prefix: 'foo',
          digest: :none,
          timestamp_type: :invalid_type
        )
      end

      it { expect { subject }.to raise_error(Glueby::Contract::Errors::InvalidTimestampType) }
    end
  end

  describe '#save!' do
    subject { contract.save! }

    context 'Use TestWallet' do
      let(:contract) do
        Glueby::Contract::Timestamp.new(
          wallet: wallet,
          content: "\01",
          prefix: 'prefix'
        )
      end
      let(:wallet) { TestWallet.new(internal_wallet) }
      let(:internal_wallet) { TestInternalWallet.new }
      let(:unspents) do
        [
          {
            txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
            script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
            vout: 0,
            amount: 100_000_000,
            finalized: false
          }, {
          txid: 'd49c8038943d37c2723c9c7a1c4ea5c3738a9bad5827ddc41e144ba6aef36db',
          script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
          vout: 1,
          amount: 100_000_000,
          finalized: true
        }, {
          txid: '1d49c8038943d37c2723c9c7a1c4ea5c3738a9bad5827ddc41e144ba6aef36db',
          script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
          vout: 2,
          amount: 50_000_000,
          finalized: true
        }, {
          txid: '864247cd4cae4b1f5bd3901be9f7a4ccba5bdea7db1d8bbd78b944da9cf39ef5',
          vout: 0,
          script_pubkey: '21c3eb2b846463430b7be9962843a97ee522e3dc0994a0f5e2fc0aa82e20e67fe893bc76a914bfeca7aed62174a7c60ebc63c7bd797bad46157a88ac',
          amount: 1,
          finalized: true
        }, {
          txid: 'f14b29639483da7c8d17b7b7515da4ff78b91b4b89434e7988ab1bc21ab41377',
          vout: 0,
          script_pubkey: '21c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016bc76a914fc688c091d91789ccda7a27bd8d88be9ae4af58e88ac',
          amount: 100_000,
          finalized: true
        }, {
          txid: '100c4dc65ea4af8abb9e345b3d4cdcc548bb5e1cdb1cb3042c840e147da72fa2',
          vout: 0,
          script_pubkey: '21c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3bc76a9144f15d2203821d7ea719314126b79bd1e530fc97588ac',
          amount: 100_000,
          finalized: true
        }, {
          txid: 'a3f20bc94c8d77c35ba1770116d2b34375475a4194d15f76442636e9f77d50d9',
          vout: 2,
          script_pubkey: '21c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3bc76a9144f15d2203821d7ea719314126b79bd1e530fc97588ac',
          amount: 100_000,
          finalized: true
        }
        ]
      end

      before do
        allow(Glueby::Wallet).to receive(:load).and_return(wallet)
        allow(internal_wallet).to receive(:list_unspent).and_return(unspents)
      end

      it 'create transaction' do
        txid = subject
        expect(txid).to eq '0c68d54805d167353d49a034a46133e992821a2cfac0f12209aa26dc03a4d97d'
        expect(contract.tx.inputs.size).to eq 1
        expect(contract.tx.outputs.size).to eq 2
        expect(contract.tx.outputs[0].value).to eq 0
        expect(contract.tx.outputs[0].script_pubkey.op_return?).to be_truthy
        expect(contract.tx.outputs[0].script_pubkey.op_return_data[0...6]).to eq "prefix"
        expect(contract.tx.outputs[0].script_pubkey.op_return_data[6..]).to eq "4bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459a"
        expect(contract.tx.outputs[1].value).to eq 99_990_000
      end

      it 'create a record in glueby_timestamps table' do
        expect { subject }.to change { Glueby::Contract::AR::Timestamp.count }.by(1)
      end

      context 'hex string' do
        let(:contract) do
          Glueby::Contract::Timestamp.new(
            wallet: wallet,
            content: 'ed7002b439e9ac845f22357d822bac1444730fbdb6016d3ec9432297b9ec9f73',
            prefix: 'e7a2e8b216'
          )
        end

        it 'create transaction' do
          txid = subject
          expect(txid).to eq 'a6fd59cde42206a0caaa9fadbe3ce397378a90eb9856171ea1e8ef92025f0e86'
          expect(contract.tx.inputs.size).to eq 1
          expect(contract.tx.outputs.size).to eq 2
          expect(contract.tx.outputs[0].value).to eq 0
          expect(contract.tx.outputs[0].script_pubkey.op_return?).to be_truthy
          expect(contract.tx.outputs[0].script_pubkey.op_return_data[0...10]).to eq 'e7a2e8b216'
          expect(contract.tx.outputs[0].script_pubkey.op_return_data[10..]).to eq '9be8de7297ef35c78e2842039755ad0240c8cb405f063fb0d74a85bc8d1dd158'
          expect(contract.tx.outputs[1].value).to eq 99_990_000
        end
      end

      context 'multibyte characters' do
        let(:contract) do
          Glueby::Contract::Timestamp.new(
            wallet: wallet,
            content: 'タピルス',
            prefix: 'あいうえお'
          )
        end

        it 'create transaction' do
          txid = subject
          expect(txid).to eq '0576157a00634472eb77aa475c1d8f80ce3ad01f57747e52e8bef46dca0c6e1e'
          expect(contract.tx.inputs.size).to eq 1
          expect(contract.tx.outputs.size).to eq 2
          expect(contract.tx.outputs[0].value).to eq 0
          expect(contract.tx.outputs[0].script_pubkey.op_return?).to be_truthy
          expect(contract.tx.outputs[0].script_pubkey.op_return_data[0...15].force_encoding('UTF-8')).to eq 'あいうえお'
          expect(contract.tx.outputs[0].script_pubkey.op_return_data[15..]).to eq '6cc7d38ba8216e215198eff6c4dc854830f024794410541b892b4571a55b7dd4'
          expect(contract.tx.outputs[1].value).to eq 99_990_000
        end
      end

      context 'if already broadcasted' do
        before { contract.save! }

        it { expect { subject }.to raise_error(Glueby::Contract::Errors::TxAlreadyBroadcasted) }
      end

      context 'if digest is :none' do
        let(:contract) do
          Glueby::Contract::Timestamp.new(
            wallet: wallet,
            content: 'Content for Timestamp',
            prefix: 'TIMESTAMPAPP',
            digest: :none
          )
        end

        it 'create transaction for content that is not digested' do
          subject
          expect(contract.tx.inputs.size).to eq 1
          expect(contract.tx.outputs.size).to eq 2
          expect(contract.tx.outputs[0].value).to eq 0
          expect(contract.tx.outputs[0].script_pubkey.op_return?).to be_truthy
          expect(contract.tx.outputs[0].script_pubkey.op_return_data[0...12].force_encoding('UTF-8')).to eq 'TIMESTAMPAPP'
          expect(contract.tx.outputs[0].script_pubkey.op_return_data[12..].force_encoding('UTF-8')).to eq 'Content for Timestamp'
          expect(contract.tx.outputs[1].value).to eq 99_990_000
        end

        context 'hex string' do
          let(:contract) do
            Glueby::Contract::Timestamp.new(
              wallet: wallet,
              content: 'ed7002b439e9ac845f22357d822bac1444730fbdb6016d3ec9432297b9ec9f73',
              prefix: 'e7a2e8b216',
              digest: :none
            )
          end

          it 'create transaction' do
            txid = subject
            expect(txid).to eq 'ae96f7cb24c3619d0610db8dbdb2ea280a80f1dcff0fc410d494b01688483c29'
            expect(contract.tx.inputs.size).to eq 1
            expect(contract.tx.outputs.size).to eq 2
            expect(contract.tx.outputs[0].value).to eq 0
            expect(contract.tx.outputs[0].script_pubkey.op_return?).to be_truthy
            expect(contract.tx.outputs[0].script_pubkey.op_return_data[0...10]).to eq 'e7a2e8b216'
            expect(contract.tx.outputs[0].script_pubkey.op_return_data[10..]).to eq 'ed7002b439e9ac845f22357d822bac1444730fbdb6016d3ec9432297b9ec9f73'
            expect(contract.tx.outputs[1].value).to eq 99_990_000
          end
        end

        context 'multibyte characters' do
          let(:contract) do
            Glueby::Contract::Timestamp.new(
              wallet: wallet,
              content: 'タピルス',
              prefix: 'あいうえお',
              digest: :none
            )
          end

          it 'create transaction' do
            txid = subject
            expect(txid).to eq 'f05dc2a4d1fb009940bf6e5736b606609b5abe3ba0c1d4f8cfc56149da498c19'
            expect(contract.tx.inputs.size).to eq 1
            expect(contract.tx.outputs.size).to eq 2
            expect(contract.tx.outputs[0].value).to eq 0
            expect(contract.tx.outputs[0].script_pubkey.op_return?).to be_truthy
            expect(contract.tx.outputs[0].script_pubkey.op_return_data[0...15].force_encoding('UTF-8')).to eq 'あいうえお'
            expect(contract.tx.outputs[0].script_pubkey.op_return_data[15..].force_encoding('UTF-8')).to eq 'タピルス'
            expect(contract.tx.outputs[1].value).to eq 99_990_000
          end
        end
      end

      context 'if digest is :double_sha256' do
        let(:contract) do
          Glueby::Contract::Timestamp.new(
            wallet: wallet,
            content: "01",
            prefix: '',
            digest: :double_sha256
          )
        end

        it 'create transaction for double sha256 digested content' do
          subject
          expect(contract.tx.inputs.size).to eq 1
          expect(contract.tx.outputs.size).to eq 2
          expect(contract.tx.outputs[0].value).to eq 0
          expect(contract.tx.outputs[0].script_pubkey.op_return?).to be_truthy
          expect(contract.tx.outputs[0].script_pubkey.op_return_data).to eq 'bf3ae3deccfdee0ebf03fc924aea3dad4b1068acdd27e98d9e6cc9a140e589d1'
          expect(contract.tx.outputs[1].value).to eq 99_990_000
        end

        context 'hex string' do
          let(:contract) do
            Glueby::Contract::Timestamp.new(
              wallet: wallet,
              content: 'ed7002b439e9ac845f22357d822bac1444730fbdb6016d3ec9432297b9ec9f73',
              prefix: 'e7a2e8b216',
              digest: :double_sha256
            )
          end

          it 'create transaction' do
            txid = subject
            expect(txid).to eq 'c95a838214e274842ee6cace961bcbb0974f7ca0f7100c60e5fb6142d4d7b609'
            expect(contract.tx.inputs.size).to eq 1
            expect(contract.tx.outputs.size).to eq 2
            expect(contract.tx.outputs[0].value).to eq 0
            expect(contract.tx.outputs[0].script_pubkey.op_return?).to be_truthy
            expect(contract.tx.outputs[0].script_pubkey.op_return_data[0...10]).to eq 'e7a2e8b216'
            expect(contract.tx.outputs[0].script_pubkey.op_return_data[10..]).to eq '9f1870eb2a0e780a98f977e19de9679dccb084be928fef57bd1b11751d323d98'
            expect(contract.tx.outputs[1].value).to eq 99_990_000
          end
        end
      end

      context 'if use utxo provider', active_record: true do
        let(:contract) do
          Glueby::Contract::Timestamp.new(
            wallet: wallet,
            content: "\01",
            prefix: '',
            utxo_provider: utxo_provider
          )
        end
        # Utxo provider use utxos whose value is UtxoProvider#default_value
        let(:unspents) do
          (0...20).map do |i|
            {
              txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
              script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
              vout: i,
              amount: 1_000,
              finalized: true
            }
          end
        end

        let(:utxo_provider) { Glueby::UtxoProvider.instance }
        let(:wallet_adapter) { double(:wallet_adapter) }

        before do
          Glueby::Internal::Wallet.wallet_adapter = wallet_adapter
          allow(wallet_adapter).to receive(:load_wallet)
          allow(utxo_provider).to receive(:wallet).and_return(internal_wallet)
        end

        after { Glueby::Internal::Wallet.wallet_adapter = nil }

        it 'broadcast 2 transactions' do
          expect(internal_wallet).to receive(:broadcast).twice
          subject
        end
      end
    end

    context 'if type is trackable', active_record: true do
      let(:contract) do
        Glueby::Contract::Timestamp.new(
          wallet: wallet,
          content: 'bar',
          prefix: 'foo',
          digest: :none,
          timestamp_type: :trackable
        )
      end

      let(:active_record_wallet) { Glueby::Internal::Wallet::AR::Wallet.find_by(wallet_id: wallet.id) }
      let(:key) { active_record_wallet.keys.create(purpose: :receive) }

      before do
        Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new
        Glueby::Internal::Wallet::AR::Utxo.create(
          txid: '0000000000000000000000000000000000000000000000000000000000000000',
          index: 0,
          value: 100_000_000,
          script_pubkey: key.to_p2pkh.to_hex,
          status: :finalized,
          key: key
        )
        allow(Glueby::Internal::RPC).to receive(:client).and_return(double(:rcp_client))
        allow(Glueby::Internal::RPC.client).to receive(:sendrawtransaction).and_return('a01d8a6bf7bef5719ada2b7813c1ce4dabaf8eb4ff22791c67299526793b511c')
      end

      let(:wallet) { Glueby::Wallet.create }
      it 'create pay-to-contract transaction' do
        subject
        expect(contract.tx.inputs.size).to eq 1
        expect(contract.tx.outputs.size).to eq 2
        expect(contract.tx.outputs[0].value).to eq 1_000
        expect(contract.tx.outputs[0].script_pubkey.op_return?).to be_falsy
        expect(contract.tx.outputs[0].script_pubkey.p2pkh?).to be_truthy
        expect(contract.tx.outputs[1].value).to eq 99_989_000
        expect(contract.p2c_address).not_to be_nil
        expect(contract.payment_base).not_to be_nil
      end

      it 'the wallet never store the UTXO of the created trackable timestamp' do
        subject
        result = wallet.internal_wallet.list_unspent(false, :all).find { |i| i[:txid] == contract.txid && i[:vout] == 0 }
        expect(result).to be_nil
      end
    end

    context 'if type is trackable and update existing timestamps', active_record: true do
      let(:contract) do
        Glueby::Contract::Timestamp.new(
          wallet: updater,
          content: 'updated',
          prefix: 'foo',
          digest: :none,
          timestamp_type: :trackable,
          prev_timestamp_id: Glueby::Contract::AR::Timestamp.find_by(txid: prev_contract.txid).id
        )
      end

      let(:prev_contract) do
        Glueby::Contract::Timestamp.new(
          wallet: wallet,
          content: 'bar',
          prefix: 'foo',
          digest: :none,
          timestamp_type: :trackable
        )
      end

      let(:active_record_wallet) { Glueby::Internal::Wallet::AR::Wallet.find_by(wallet_id: wallet.id) }
      let(:key) { active_record_wallet.keys.create(purpose: :receive) }
      let(:wallet) { Glueby::Wallet.create }
      let(:updater) { wallet }

      before do
        Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new
        2.times do |i|
          Glueby::Internal::Wallet::AR::Utxo.create(
            txid: '0000000000000000000000000000000000000000000000000000000000000000',
            index: i,
            value: 100_000_000,
            script_pubkey: key.to_p2pkh.to_hex,
            status: :finalized,
            key: key
          )
          end
        allow(Glueby::Internal::RPC).to receive(:client).and_return(double(:rcp_client))
        allow(Glueby::Internal::RPC.client).to receive(:sendrawtransaction).and_return('a01d8a6bf7bef5719ada2b7813c1ce4dabaf8eb4ff22791c67299526793b511c')

        prev_contract.save!
      end

      it 'create pay-to-contract transaction' do
        subject
        expect(contract.tx.inputs.size).to eq 2
        expect(contract.tx.outputs.size).to eq 2
        expect(contract.tx.outputs[0].value).to eq 1_000
        expect(contract.tx.outputs[0].script_pubkey.op_return?).to be_falsy
        expect(contract.tx.outputs[0].script_pubkey.p2pkh?).to be_truthy
        expect(contract.tx.outputs[1].value).to eq 99_990_000
        expect(contract.p2c_address).not_to be_nil
        expect(contract.payment_base).not_to be_nil
      end

      context 'when 3rd-party is trying to update timestamp' do
        let(:updater) { Glueby::Wallet.create }
        let(:another_active_record_wallet) { Glueby::Internal::Wallet::AR::Wallet.find_by(wallet_id: updater.id) }
        let(:another_key) { another_active_record_wallet.keys.create(purpose: :receive) }

        before do
          # Utxo for fee (in another wallet)
          2.times do |i|
            Glueby::Internal::Wallet::AR::Utxo.create(
              txid: '0000000000000000000000000000000000000000000000000000000000000001',
              index: i,
              value: 100_000_000,
              script_pubkey: another_key.to_p2pkh.to_hex,
              status: :finalized,
              key: another_key
            )
          end
        end

        it 'can not broadcast transaction' do
          expect { subject }.to raise_error(Glueby::Contract::Errors::FailedToBroadcast, /failed to broadcast \(id=, reason=The previous timestamp\(id: [0-9]+\) was created by the different user/)
        end
      end
    end
  end
end
