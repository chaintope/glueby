RSpec.describe 'Timestamp Contract', functional: true do
  context 'use activerecord wallet adapter', active_record: true do
    before do
      Glueby.configuration.wallet_adapter = :activerecord
    end

    after do
      Glueby::Internal::Wallet.wallet_adapter = nil
    end

    context 'bear fees by sender' do
      let(:fee) { 10_000 }
      let(:fee_estimator) { Glueby::Contract::FixedFeeEstimator.new(fixed_fee: fee) }
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
        Glueby::Contract::AR::Timestamp.create(wallet_id: sender.id, content: "\xFF\xFF\xFF", prefix: 'app')
        Rake.application['glueby:contract:timestamp:create'].execute

        expect(sender.balances(false)['']).to eq(before_balance - fee)
      end
    end

    context 'bear fees by UtxoProvider' do
      include_context 'setup fee provider'

      let(:fee) { 10_000 }
      let(:fee_estimator) { Glueby::Contract::FixedFeeEstimator.new(fixed_fee: fee) }
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
        Glueby::Contract::AR::Timestamp.create(wallet_id: sender.id, content: "\xFF\xFF\xFF", prefix: 'app')
        Rake.application['glueby:contract:timestamp:create'].execute

        expect(sender.balances(false)['']).to eq(before_balance)
      end
    end
  end
end