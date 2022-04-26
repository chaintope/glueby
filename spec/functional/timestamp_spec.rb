RSpec.describe 'Timestamp Contract', functional: true do
  context 'use activerecord wallet adapter', active_record: true do
    before do
      Glueby.configuration.wallet_adapter = :activerecord
      Glueby::BlockSyncer.register_syncer(Glueby::Contract::Timestamp::Syncer)
    end

    after do
      Glueby::Internal::Wallet.wallet_adapter = nil
      Glueby::BlockSyncer.unregister_syncer(Glueby::Contract::Timestamp::Syncer)
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

        it do
          # Add timestamp job to timestamps table
          ar = Glueby::Contract::AR::Timestamp.create(wallet_id: sender.id, content: "\xFF\xFF\xFF", prefix: 'app', timestamp_type: :trackable)
          expect(ar.status).to eq('init')
          expect(ar.txid).to be_nil
          expect(ar.p2c_address).to be_nil
          expect(ar.payment_base).to be_nil

          # Broadcast tx for the timestamp job
          # and it should consume one UTXO in UtxoProvider
          expect do
            Rake.application['glueby:contract:timestamp:create'].execute
          end.to change { Glueby::UtxoProvider.instance.wallet.list_unspent.count }.by(-1)

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
          end.to change { Glueby::UtxoProvider.instance.wallet.list_unspent.count }.by(-1)

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
            .and change { Glueby::UtxoProvider.instance.wallet.list_unspent.count }.by(0) # never consume UTXO pool and never broadcast any tx.
        end
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

        it 'use Glueby::Contract::Timestamp directly' do
          timestamp = Glueby::Contract::Timestamp.new(
            wallet: sender,
            content: "\xFF\xFF\xFF",
            prefix: 'app',
            utxo_provider: Glueby::UtxoProvider.instance
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
          end.to change { Glueby::UtxoProvider.instance.wallet.list_unspent.count }.by(-1)
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
      end
    end
  end
end