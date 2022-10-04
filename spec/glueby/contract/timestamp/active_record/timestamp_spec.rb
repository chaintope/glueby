
RSpec.describe 'Glueby::Contract::AR::Timestamp', active_record: true do
  shared_context 'timestamp can be saved and broadcasted' do
    let(:timestamp) do
      Glueby::Contract::AR::Timestamp.new(
        wallet_id: '00000000000000000000000000000000',
        content: "\xFF\xFF\xFF",
        prefix: 'app',
        timestamp_type: timestamp_type,
        prev_id: prev_id
      )
    end
    let(:timestamp_type) { :simple }
    let(:prev_id) { nil }
    let(:rpc) { double('mock') }
    let(:wallet) { Glueby::Wallet.create }

    let(:address) { wallet.internal_wallet.receive_address }
    let(:key) do
      Glueby::Internal::Wallet::AR::Key.find_by(script_pubkey: Tapyrus::Script.parse_from_addr(address).to_hex)
    end

    before do
      Glueby.configuration.wallet_adapter = :activerecord
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: 'aa' * 32,
        index: 0,
        value: 20_000,
        script_pubkey: '76a914f9cfb93abedaef5b725c986efb31cca730bc0b3d88ac',
        status: :finalized,
        key: key
      )

      allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)
      allow(rpc).to receive(:sendrawtransaction).and_return('0000000000000000000000000000000000000000000000000000000000000000')
      allow(rpc).to receive(:generatetoaddress).and_return('0000000000000000000000000000000000000000000000000000000000000000')
      allow(Glueby::Wallet).to receive(:load).with("00000000000000000000000000000000").and_return(wallet)
    end

    after { Glueby::Internal::Wallet.wallet_adapter = nil }
  end

  describe 'initialize' do
    let(:timestamp) do
      Glueby::Contract::AR::Timestamp.create!(
        wallet_id: '00000000000000000000000000000000',
        content: "\xFF\xFF\xFF",
        prefix: 'app',
        timestamp_type: timestamp_type
      )
    end
    let(:timestamp_type) { :simple }

    context 'unknown timestamp type' do
      let(:timestamp_type) { :unknown }

      it do
        expect { timestamp }.to raise_error(Glueby::ArgumentError, "'unknown' is not a valid timestamp_type")
      end
    end

    context 'belongs_to required by default is true' do
      before do
        # From rails 6, true is the default value
        ActiveRecord::Base.belongs_to_required_by_default = true
      end

      after do
        ActiveRecord::Base.belongs_to_required_by_default = nil
      end

      it do
        expect { timestamp }.not_to raise_error
      end
    end
  end

  describe 'validation' do
    let(:valid_attributes) do
      {
        wallet_id: '00000000000000000000000000000000',
        content: "\xFF\xFF\xFF",
        prefix: 'app',
        timestamp_type: 'trackable'
      }
    end

    it 'valid trackable timestamp' do
      Glueby::Contract::AR::Timestamp.create!(valid_attributes)
    end

    it 'valid simple timestamp multiple tiems' do
      2.times do
        Glueby::Contract::AR::Timestamp.create!(valid_attributes.merge(timestamp_type: :simple)).prev_id
      end
    end

    context 'set prev_id to simple timestamp' do
      it 'error' do
        expect { Glueby::Contract::AR::Timestamp.create!(valid_attributes.merge(timestamp_type: :simple, prev_id: 0)) }
          .to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Prev The previous timestamp(id: 0) must be nil in simple timestamp')
      end
    end

    context 'the prev timestamp is not exists' do
      it 'error' do
        expect { Glueby::Contract::AR::Timestamp.create!(valid_attributes.merge(prev_id: 0)) }
          .to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Prev The previous timestamp(id: 0) not found.')
      end
    end

    context 'has prev timestamp' do
      let!(:prev) do
        Glueby::Contract::AR::Timestamp.create!(valid_attributes)
      end

      it 'valid updating trackable timestamp' do
        Glueby::Contract::AR::Timestamp.create!(valid_attributes.merge(prev_id: prev.id))
      end

      context 'the prev timestamp is already updated' do
        before do
          Glueby::Contract::AR::Timestamp.create!(valid_attributes.merge(prev_id: prev.id))
        end

        it 'error' do
          expect { Glueby::Contract::AR::Timestamp.create!(valid_attributes.merge(prev_id: prev.id)) }
            .to raise_error(ActiveRecord::RecordInvalid, /Validation failed: Prev The previous timestamp\(id: [0-9]+\) was already updated/)
        end
      end

      context 'the prev timestamp is created by the different user' do
        let!(:prev) do
          Glueby::Contract::AR::Timestamp.create!({
            wallet_id: '11111111111111111111111111111111',
            content: "\xFF\xFF\xFF",
            prefix: 'app',
            timestamp_type: 'trackable'
          })
        end

        it 'error' do
          expect { Glueby::Contract::AR::Timestamp.create!(valid_attributes.merge(prev_id: prev.id)) }
            .to raise_error(ActiveRecord::RecordInvalid, /Validation failed: Prev The previous timestamp\(id: [0-9]+\) was created by the different user/)
        end
      end

      context 'prev is simple timestamp' do
        let!(:prev) do
          Glueby::Contract::AR::Timestamp.create!(valid_attributes.merge(timestamp_type: :simple))
        end

        it 'error' do
          expect { Glueby::Contract::AR::Timestamp.create!(valid_attributes.merge(prev_id: prev.id)) }
            .to raise_error(ActiveRecord::RecordInvalid, /Validation failed: Prev The previous timestamp\(id: [0-9]+\) type must be trackable/)
        end
      end
    end
  end

  describe '#latest' do
    include_context 'timestamp can be saved and broadcasted'
    subject { timestamp.latest? }

    before do
      timestamp.save_with_broadcast!
      timestamp.reload
    end

    shared_examples 'check latest?' do
      context 'timestamp type is simple' do
        let(:timestamp_type) { :simple }

        it { is_expected.to be_falsy }
      end

      context 'timestamp type is trackable' do
        let(:timestamp_type) { :trackable }

        it { is_expected.to be_truthy }
      end
    end

    include_examples 'check latest?'

    context 'use alias name' do
      subject { timestamp.latest }
      include_examples 'check latest?'
    end
  end

  describe '#save_with_broadcast' do
    subject { timestamp.save_with_broadcast }

    let(:timestamp) do
      Glueby::Contract::AR::Timestamp.new(
        wallet_id: '00000000000000000000000000000000',
        content: "\xFF\xFF\xFF",
        prefix: 'app',
        timestamp_type: :simple
      )
    end

    context 'it doesnt not raise errors' do
      before do
        allow(timestamp).to receive(:save_with_broadcast!).and_return(true)
      end

      it do
        expect(subject).to be_truthy
      end
    end

    shared_examples 'returns false if it raises an error' do
      let(:error_class) { Glueby::Contract::Errors::FailedToBroadcast }
      before do
        allow(timestamp).to receive(:save_with_broadcast!).and_raise(error_class)
      end

      it do
        expect(subject).to be_falsey
      end
    end

    it_behaves_like 'returns false if it raises an error'
    it_behaves_like 'returns false if it raises an error' do
      let(:error_class) { Glueby::Contract::Errors::PrevTimestampNotFound }
    end
    it_behaves_like 'returns false if it raises an error' do
      let(:error_class) { Glueby::Contract::Errors::PrevTimestampIsNotTrackable }
    end
    it_behaves_like 'returns false if it raises an error' do
      let(:error_class) { Glueby::Contract::Errors::PrevTimestampAlreadyUpdated }
    end
  end

  describe '#save_with_broadcast!' do
    subject { timestamp.save_with_broadcast! }

    include_context 'timestamp can be saved and broadcasted'

    it do
      expect(rpc).to receive(:sendrawtransaction).once
      subject
    end

    it do
      subject
      expect(timestamp.status).to eq "unconfirmed"
      expect(timestamp.p2c_address).to be_nil
      expect(timestamp.payment_base).to be_nil
    end

    context 'raises Tapyrus::RPC::Error' do
      before do
        error = Tapyrus::RPC::Error.new(500, nil, nil)
        allow(error).to receive(:message).and_return('error message')
        allow(rpc).to receive(:sendrawtransaction).and_raise(error)
      end

      it do
        expect { subject }.to raise_error(Glueby::Contract::Errors::FailedToBroadcast, 'failed to broadcast (id=, reason=error message)')
      end
    end

    context 'with trackable type' do
      let(:timestamp_type) { :trackable }

      it do
        expect(rpc).to receive(:sendrawtransaction).once
        subject
      end

      it do
        subject
        expect(timestamp.status).to eq "unconfirmed"
        expect(timestamp.p2c_address).not_to be_nil
        expect(timestamp.payment_base).not_to be_nil
      end

      context 'has prev_id' do
        context 'prev timestamp that is correspond with prev_id is not exist' do
          let(:prev_id) { 999 }

          it do
            expect { subject }.to raise_error(Glueby::Contract::Errors::PrevTimestampNotFound, 'The previous timestamp(id: 999) not found.')
          end
        end

        context 'has existing prev_id' do
          let(:prev) do
            Glueby::Contract::AR::Timestamp.create(
              wallet_id: '00000000000000000000000000000000',
              content: "\xFF\xFF\xFF",
              prefix: 'app',
              timestamp_type: :trackable
            )
          end
          let!(:prev_id) do
            prev.save_with_broadcast!
            prev.id
          end

          before do
            # Prepare an UTXO for previous timestamp tx.
            Glueby::Internal::Wallet::AR::Utxo.create(
              txid: 'aa' * 32,
              index: 1,
              value: 20_000,
              script_pubkey: '76a914f9cfb93abedaef5b725c986efb31cca730bc0b3d88ac',
              status: :finalized,
              key: key
            )
          end

          it do
            expect(rpc).to receive(:sendrawtransaction).once
            subject
          end

          it do
            subject
            timestamp.reload
            expect(timestamp.status).to eq "unconfirmed"
            expect(timestamp.p2c_address).not_to be_nil
            expect(timestamp.payment_base).not_to be_nil
            expect(timestamp.latest).to be_truthy
          end

          it 'update previous timestamp\'s latest falg to false' do
            subject
            expect(prev.reload.latest).to be_falsey
          end

          context 'previous timestamp type is not trackable' do
            let!(:prev_id) do
              prev = Glueby::Contract::AR::Timestamp.create(
                wallet_id: '00000000000000000000000000000000',
                content: "\xFF\xFF\xFF",
                prefix: 'app',
                timestamp_type: :simple
              )
              prev.save_with_broadcast!
              prev.id
            end

            it do
              expect { subject }.to raise_error(Glueby::Contract::Errors::PrevTimestampIsNotTrackable, /The previous timestamp\(id: [0-9]+\) type must be trackable/)
            end
          end

          context 'previous timestamp is not created by different user' do
            before do
              allow(Glueby::Wallet).to receive(:load).with(another_wallet.internal_wallet.id).and_return(another_wallet)
            end

            let(:prev) do
              Glueby::Contract::AR::Timestamp.create(
                wallet_id: another_wallet.internal_wallet.id,
                content: "\xFF\xFF\xFF",
                prefix: 'app',
                timestamp_type: :trackable
              )
            end
            let(:prev_id) { prev.id }
            let(:another_wallet) { Glueby::Wallet.create }

            it do
              expect { subject }.to raise_error(Glueby::Contract::Errors::FailedToBroadcast, /failed to broadcast \(id=, reason=The previous timestamp\(id: [0-9]+\) was created by the different user/)
            end
          end
        end
      end
    end

    context 'use utxo provider' do
      let(:provider_wallet) do
        Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: Glueby::UtxoProvider::WALLET_ID)
      end
      let(:key) { provider_wallet.keys.create(purpose: :receive) }
      let(:utxo_provider) { Glueby::UtxoProvider.instance }

      before do
        Glueby.configuration.enable_utxo_provider!
        Glueby::UtxoProvider.instance


        # 20 Utxos are pooled.
        (0...21).each do |i|
          Glueby::Internal::Wallet::AR::Utxo.create(
            txid: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
            index: i,
            script_pubkey: '76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
            key: key,
            value: 1_000,
            status: :finalized
          )
        end
      end
      after { Glueby.configuration.disable_utxo_provider! }

      it do
        expect(rpc).to receive(:sendrawtransaction).twice
        subject
        expect(timestamp.status).to eq "unconfirmed"
        expect(timestamp.p2c_address).to be_nil
        expect(timestamp.payment_base).to be_nil
      end
    end
  end
end
