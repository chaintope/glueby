RSpec.describe 'Timestamp Contract', functional: true, mysql: true do
  before do
    Glueby::BlockSyncer.register_syncer(Glueby::Contract::Timestamp::Syncer)
  end

  after do
    Glueby::BlockSyncer.unregister_syncer(Glueby::Contract::Timestamp::Syncer)
  end

  shared_examples 'unlock UTXOs if the timestamp txs are not broadcasted' do
    subject { timestamp.save! }
    let(:utxo_provider) { Glueby::UtxoProvider.new }
    let(:sender) { Glueby::Wallet.create }
    let(:rpc) { double('mock') }
    let(:timestamp_type) { :simple }
    let(:timestamp) do
      Glueby::Contract::Timestamp.new(
        wallet: sender,
        content: "\xFF\xFF\xFF",
        prefix: 'app',
        timestamp_type: timestamp_type,
        utxo_provider: utxo_provider,
        hex: true
      )
    end

    context 'broadcasting funding tx is failure' do
      before do
        allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)
        allow(rpc).to receive(:sendrawtransaction).and_raise(Tapyrus::RPC::Error.new(
          '500',
          'Internal Server Error',
          { 'code' => -25, 'message' => 'Missing inputs'}))
      end

      it 'doesn\'t create unlocked UTXOs' do
        expect { subject }.to raise_error(Glueby::Contract::Errors::FailedToBroadcast)
        expect(Glueby::Internal::Wallet::AR::Utxo.where('locked_at is not null').count).to eq 0
      end
    end

    context 'broadcasting timestamp tx is failure' do
      before do
        allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)

        call_count = 0
        allow(rpc).to receive(:sendrawtransaction) do |tx|
          if call_count == 0
            Tapyrus::Tx.parse_from_payload(tx.htb).txid
          elsif call_count == 1
            raise Tapyrus::RPC::Error.new(
              '500',
              'Internal Server Error',
              { 'code' => -25, 'message' => 'Missing inputs'})
          end

          call_count += 1
        end
      end

      it 'doesn\'t create unlocked UTXOs' do
        expect { subject }.to raise_error(Glueby::Contract::Errors::FailedToBroadcast)
        expect(Glueby::Internal::Wallet::AR::Utxo.where('locked_at is not null').count).to eq 0
      end
    end
  end

  context 'trackable type' do
    context 'bear fees by sender' do
      let(:fee) { 10_000 }
      let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new(fixed_fee: fee) }
      let(:sender) { Glueby::Wallet.create }
      let(:before_balance) { sender.balances(false)[''] }

      before do
        process_block(to_address: sender.internal_wallet.receive_address)
        before_balance
      end

      it 'use rake task' do
        # Add timestamp job to timestamps table
        ar = Glueby::Contract::AR::Timestamp.create(wallet_id: sender.id, content: "\xFF\xFF\xFF", prefix: 'app', timestamp_type: :trackable)
        expect(ar.status).to eq('init')
        expect(ar.txid).to be_nil
        expect(ar.p2c_address).to be_nil
        expect(ar.payment_base).to be_nil

        # Broadcast tx for the timestamp job
        Rake.application['glueby:contract:timestamp:create'].execute
        ar.reload
        expect(sender.balances(false)['']).to eq(before_balance - Glueby::Contract::Timestamp::P2C_DEFAULT_VALUE - fee)
        expect(ar.status).to eq('unconfirmed')
        expect(ar.txid).not_to be_nil
        expect(ar.p2c_address).not_to be_nil
        expect(ar.payment_base).not_to be_nil


        # Sync blocks, but the status is still unconfirmed because a new block is not created.
        Rake.application['glueby:block_syncer:start'].execute
        ar.reload
        expect(ar.status).to eq('unconfirmed')

        process_block

        # Sync blocks, then the status is changed to confirmed because of generating a block.
        Rake.application['glueby:block_syncer:start'].execute
        ar.reload
        expect(ar.status).to eq('confirmed')
      end
    end

    context 'UtxoProvider provides UTXOs' do
      include_context 'setup utxo provider'

      let(:sender) { Glueby::Wallet.create }
      let(:utxo_provider) { Glueby::UtxoProvider.new }

      it do
        # Add timestamp job to timestamps table
        ar = Glueby::Contract::AR::Timestamp.create(wallet_id: sender.id, content: "\xFF\xFF\xFF", prefix: 'app', timestamp_type: :trackable)
        expect(ar.status).to eq('init')
        expect(ar.txid).to be_nil
        expect(ar.p2c_address).to be_nil
        expect(ar.payment_base).to be_nil

        # Broadcast tx for the timestamp job
        # and it should consume two UTXOs in UtxoProvider
        # It creates two TXs, the one is funding tx that is created by UTXO Provider to provide a tapyrus input
        # to the timestamp tx. The funding tx has two inputs from UTXO pool and the input amount is 8000 tapyrus.
        # The timestamp TX requires 3000 tapyrus, so the funding tx has 4000 tapyrus output to the timestamp tx.
        # The fee of the funding tx is 2000 tapyrus, this is fixed by FixedFeeEstimator. And the change is 3000
        # tapyrus to the UTXO Provider's wallet. So, it should consume two UTXOs from UTXO Provider.
        expect do
          Rake.application['glueby:contract:timestamp:create'].execute
        end.to change { utxo_provider.wallet.list_unspent.count }.by(-2)

        ar.reload
        expect(sender.balances(false)['']).to be_nil
        expect(ar.status).to eq('unconfirmed')
        expect(ar.txid).not_to be_nil
        expect(ar.p2c_address).not_to be_nil
        expect(ar.payment_base).not_to be_nil

        # Sync blocks, but the status is still unconfirmed because a new block is not created.
        Rake.application['glueby:block_syncer:start'].execute
        ar.reload
        expect(ar.status).to eq('unconfirmed')

        process_block

        # Sync blocks, then the status is changed to confirmed because of generating a block.
        Rake.application['glueby:block_syncer:start'].execute
        ar.reload
        expect(ar.status).to eq('confirmed')

        # Update the timestamp
        update_ar = Glueby::Contract::AR::Timestamp.create(
          wallet_id: sender.id,
          content: "1234".htb,
          prefix: 'app',
          timestamp_type: :trackable,
          prev_id: ar.id
        )
        expect do
          Rake.application['glueby:contract:timestamp:create'].execute
        end.to change { utxo_provider.wallet.list_unspent.count }.by(-2)

        update_ar.reload
        # expect(sender.balances(false)['']).to be_nil
        expect(update_ar.status).to eq('unconfirmed')
        expect(update_ar.txid).not_to be_nil
        expect(update_ar.p2c_address).not_to be_nil
        expect(update_ar.payment_base).not_to be_nil

        process_block

        # Sync blocks, then the status is changed to confirmed because of generating a block.
        Rake.application['glueby:block_syncer:start'].execute
        update_ar.reload
        expect(update_ar.status).to eq('confirmed')

        # Try to update already updated timestamp
        timestamp = Glueby::Contract::AR::Timestamp.new(
          wallet_id: sender.id,
          content: "1234".htb,
          prefix: 'app',
          timestamp_type: :trackable,
          prev_id: ar.id
        )
        expect { timestamp.save_with_broadcast! }
          .to raise_error(
            Glueby::Contract::Errors::PrevTimestampAlreadyUpdated,
            /The previous timestamp\(id: [0-9]+\) was already updated/
          )
          .and change { utxo_provider.wallet.list_unspent.count }.by(0) # never consume UTXO pool and never broadcast any tx.
      end
      
      context 'hex option is enabled' do
        it do
          # Add timestamp job to timestamps table
          ar = Glueby::Contract::AR::Timestamp.create(wallet_id: sender.id, content: "FFFFFF", prefix: '071222', timestamp_type: :trackable, hex: true)
          expect(ar.status).to eq('init')
          expect(ar.txid).to be_nil
          expect(ar.p2c_address).to be_nil
          expect(ar.payment_base).to be_nil
  
          # Broadcast tx for the timestamp job
          # and it should consume two UTXOs in UtxoProvider
          # It creates two TXs, the one is funding tx that is created by UTXO Provider to provide a tapyrus input
          # to the timestamp tx. The funding tx has two inputs from UTXO pool and the input amount is 8000 tapyrus.
          # The timestamp TX requires 3000 tapyrus, so the funding tx has 4000 tapyrus output to the timestamp tx.
          # The fee of the funding tx is 2000 tapyrus, this is fixed by FixedFeeEstimator. And the change is 3000
          # tapyrus to the UTXO Provider's wallet. So, it should consume two UTXOs from UTXO Provider.
          expect do
            Rake.application['glueby:contract:timestamp:create'].execute
          end.to change { utxo_provider.wallet.list_unspent.count }.by(-2)
  
          ar.reload
          expect(sender.balances(false)['']).to be_nil
          expect(ar.status).to eq('unconfirmed')
          expect(ar.txid).not_to be_nil
          expect(ar.p2c_address).not_to be_nil
          expect(ar.payment_base).not_to be_nil
  
          # Sync blocks, but the status is still unconfirmed because a new block is not created.
          Rake.application['glueby:block_syncer:start'].execute
          ar.reload
          expect(ar.status).to eq('unconfirmed')
  
          process_block
  
          # Sync blocks, then the status is changed to confirmed because of generating a block.
          Rake.application['glueby:block_syncer:start'].execute
          ar.reload
          expect(ar.status).to eq('confirmed')
  
          # Update the timestamp
          update_ar = Glueby::Contract::AR::Timestamp.create(
            wallet_id: sender.id,
            content: "1234",
            prefix: '071222',
            timestamp_type: :trackable,
            prev_id: ar.id,
            hex: true
          )
          expect do
            Rake.application['glueby:contract:timestamp:create'].execute
          end.to change { utxo_provider.wallet.list_unspent.count }.by(-2)
  
          update_ar.reload
          # expect(sender.balances(false)['']).to be_nil
          expect(update_ar.status).to eq('unconfirmed')
          expect(update_ar.txid).not_to be_nil
          expect(update_ar.p2c_address).not_to be_nil
          expect(update_ar.payment_base).not_to be_nil
  
          process_block
  
          # Sync blocks, then the status is changed to confirmed because of generating a block.
          Rake.application['glueby:block_syncer:start'].execute
          update_ar.reload
          expect(update_ar.status).to eq('confirmed')
  
          # Try to update already updated timestamp
          timestamp = Glueby::Contract::AR::Timestamp.new(
            wallet_id: sender.id,
            content: "1234",
            prefix: '071222',
            timestamp_type: :trackable,
            prev_id: ar.id,
            hex: true
          )
          expect { timestamp.save_with_broadcast! }
            .to raise_error(
              Glueby::Contract::Errors::PrevTimestampAlreadyUpdated,
              /The previous timestamp\(id: [0-9]+\) was already updated/
            )
            .and change { utxo_provider.wallet.list_unspent.count }.by(0) # never consume UTXO pool and never broadcast any tx.
        end
      end

      context 'work well under multi-threads' do
        let(:utxo_pool_size) { 80 }
        let(:fee_estimator_for_manage) { Glueby::Contract::FeeEstimator::Auto.new }
        let(:sender) { Glueby::Wallet.create }

        it 'broadcast transactions with no error on multi thread' do
          on_multi_thread(20) do
            timestamp = Glueby::Contract::AR::Timestamp.new(
              wallet_id: sender.id,
              content: 'ffffff',
              prefix: 'aabb',
              timestamp_type: :trackable
            )

            timestamp.save_with_broadcast!

            Glueby::Contract::AR::Timestamp.new(
              wallet_id: sender.id,
              content: "eeeeee",
              prefix: 'aabb',
              timestamp_type: :trackable,
              prev_id: timestamp.id
            ).save_with_broadcast!
          end
        end
      end

      it_behaves_like 'unlock UTXOs if the timestamp txs are not broadcasted'
    end
  end

  context 'simple type' do
    context 'bear fees by sender' do
      let(:fee) { 10_000 }
      let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new(fixed_fee: fee) }
      let(:sender) { Glueby::Wallet.create }
      let(:before_balance) { sender.balances(false)[''] }

      before do
        process_block(to_address: sender.internal_wallet.receive_address)
        before_balance
      end

      it 'use Glueby::Contract::Timestamp directly' do
        timestamp = Glueby::Contract::Timestamp.new(
          wallet: sender,
          content: "\xFF\xFF\xFF",
          prefix: 'app',
          fee_estimator: fee_estimator
        )
        timestamp.save!

        expect(sender.balances(false)['']).to eq(before_balance - fee)
      end

      it 'use rake task' do
        # Add timestamp job to timestamps table
        ar = Glueby::Contract::AR::Timestamp.create(wallet_id: sender.id, content: "\xFF\xFF\xFF", prefix: 'app')
        expect(ar.status).to eq('init')
        expect(ar.txid).to be_nil

        # Broadcast tx for the timestamp job
        Rake.application['glueby:contract:timestamp:create'].execute
        ar.reload
        expect(sender.balances(false)['']).to eq(before_balance - fee)
        expect(ar.status).to eq('unconfirmed')
        expect(ar.txid).not_to be_nil

        # Sync blocks, but the status is still unconfirmed because a new block is not created.
        Rake.application['glueby:block_syncer:start'].execute
        ar.reload
        expect(ar.status).to eq('unconfirmed')

        process_block

        # Sync blocks, then the status is changed to confirmed because of generating a block.
        Rake.application['glueby:block_syncer:start'].execute
        ar.reload
        expect(ar.status).to eq('confirmed')
      end
    end

    context 'bear fees by FeeProvider' do
      include_context 'setup fee provider'

      let(:fee) { 10_000 }
      let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new(fixed_fee: fee) }
      let(:sender) { Glueby::Wallet.create }
      let(:before_balance) { sender.balances(false)[''] }

      before do
        process_block(to_address: sender.internal_wallet.receive_address)
        before_balance
      end

      it 'use Glueby::Contract::Timestamp directly' do
        timestamp = Glueby::Contract::Timestamp.new(
          wallet: sender,
          content: "\xFF\xFF\xFF",
          prefix: 'app',
          fee_estimator: fee_estimator
        )
        timestamp.save!

        expect(sender.balances(false)['']).to eq(before_balance)
      end

      it 'use rake task' do
        # Add timestamp job to timestamps table
        ar = Glueby::Contract::AR::Timestamp.create(wallet_id: sender.id, content: "\xFF\xFF\xFF", prefix: 'app')
        expect(ar.status).to eq('init')
        expect(ar.txid).to be_nil

        # Broadcast tx for the timestamp job
        Rake.application['glueby:contract:timestamp:create'].execute
        ar.reload
        expect(sender.balances(false)['']).to eq(before_balance)
        expect(ar.status).to eq('unconfirmed')
        expect(ar.txid).not_to be_nil

        # Sync blocks, but the status is still unconfirmed because a new block is not created.
        Rake.application['glueby:block_syncer:start'].execute
        ar.reload
        expect(ar.status).to eq('unconfirmed')

        process_block

        # Sync blocks, then the status is changed to confirmed because of generating a block.
        Rake.application['glueby:block_syncer:start'].execute
        ar.reload
        expect(ar.status).to eq('confirmed')
      end
    end

    context 'UtxoProvider provides UTXOs' do
      include_context 'setup utxo provider'

      let(:sender) { Glueby::Wallet.create }
      let(:utxo_provider) { Glueby::UtxoProvider.new }

      it 'use Glueby::Contract::Timestamp directly' do
        timestamp = Glueby::Contract::Timestamp.new(
          wallet: sender,
          content: "\xFF\xFF\xFF",
          prefix: 'app',
          utxo_provider: utxo_provider
        )
        timestamp.save!

        expect(sender.balances(false)['']).to be_nil
      end

      it 'use rake task' do
        # Add timestamp job to timestamps table
        ar = Glueby::Contract::AR::Timestamp.create(wallet_id: sender.id, content: "\xFF\xFF\xFF", prefix: 'app')
        expect(ar.status).to eq('init')
        expect(ar.txid).to be_nil

        # Broadcast tx for the timestamp job
        # and it should consume one UTXO in UtxoProvider
        expect do
          Rake.application['glueby:contract:timestamp:create'].execute
        end.to change { utxo_provider.wallet.list_unspent.count }.by(-1)
        ar.reload
        expect(sender.balances(false)['']).to be_nil
        expect(ar.status).to eq('unconfirmed')
        expect(ar.txid).not_to be_nil

        # Sync blocks, but the status is still unconfirmed because a new block is not created.
        Rake.application['glueby:block_syncer:start'].execute
        ar.reload
        expect(ar.status).to eq('unconfirmed')

        process_block

        # Sync blocks, then the status is changed to confirmed because of generating a block.
        Rake.application['glueby:block_syncer:start'].execute
        ar.reload
        expect(ar.status).to eq('confirmed')
      end

      context 'work well under multi-threads' do
        let(:utxo_pool_size) { 40 }
        let(:fee_estimator_for_manage) { Glueby::Contract::FeeEstimator::Auto.new }
        let(:utxo_provider) { Glueby::UtxoProvider.new }
        let(:sender) { Glueby::Wallet.create }

        let(:timestamp_type) { :simple }

        it 'broadcast transactions with no error on multi thread' do
          on_multi_thread(20) do
            Glueby::Contract::Timestamp.new(
              wallet: sender,
              content: "\xFF\xFF\xFF",
              prefix: 'app',
              timestamp_type: timestamp_type,
              utxo_provider: utxo_provider
            ).save!
          end
        end
      end

      it_behaves_like 'unlock UTXOs if the timestamp txs are not broadcasted'
    end
  end
end