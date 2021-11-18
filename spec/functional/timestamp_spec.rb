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

    context 'bear fees by sender' do
      let(:fee) { 10_000 }
      let(:fee_estimator) { Glueby::Contract::FixedFeeEstimator.new(fixed_fee: fee) }
      let!(:sender) { Glueby::Wallet.create }
      let(:before_balance) { sender.balances(false)[''] }

      before do
        process_block(to_address: sender.internal_wallet.receive_address)
        # create labeled utxo
        process_block(to_address: sender.internal_wallet.receive_address('labeled'))
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
        # should not consume 'labeled' utxos
        expect(sender.internal_wallet.list_unspent(false, 'labeled').size).to eq(1)
        expect(sender.internal_wallet.list_unspent(false, 'labeled')[0][:amount]).to eq(5_000_000_000)
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

        # should not consume 'labeled' utxos
        expect(sender.internal_wallet.list_unspent(false, 'labeled').size).to eq(1)
        expect(sender.internal_wallet.list_unspent(false, 'labeled')[0][:amount]).to eq(5_000_000_000)
      end
    end

    context 'bear fees by UtxoProvider' do
      include_context 'setup fee provider'

      let(:fee) { 10_000 }
      let(:fee_estimator) { Glueby::Contract::FixedFeeEstimator.new(fixed_fee: fee) }
      let!(:sender) { Glueby::Wallet.create }
      let(:before_balance) { sender.balances(false)[''] }

      before do
        process_block(to_address: sender.internal_wallet.receive_address)
        # create labeled utxo
        process_block(to_address: sender.internal_wallet.receive_address('labeled'))
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

        # should not consume 'labeled' utxos
        expect(sender.internal_wallet.list_unspent(false, 'labeled').size).to eq(1)
        expect(sender.internal_wallet.list_unspent(false, 'labeled')[0][:amount]).to eq(5_000_000_000)
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

        # should not consume 'labeled' utxos
        expect(sender.internal_wallet.list_unspent(false, 'labeled').size).to eq(1)
        expect(sender.internal_wallet.list_unspent(false, 'labeled')[0][:amount]).to eq(5_000_000_000)
      end
    end
  end
end
