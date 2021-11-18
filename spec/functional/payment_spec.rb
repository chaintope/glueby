RSpec.describe 'Payment Contract', functional: true do
  context 'use activerecord wallet adapter', active_record: true do
    before do
      Glueby.configuration.wallet_adapter = :activerecord
    end

    after do
      Glueby::Internal::Wallet.wallet_adapter = nil
    end

    context 'bear fees by sender' do
      let!(:sender) { Glueby::Wallet.create }
      let!(:receiver) { Glueby::Wallet.create }
      let(:before_balance) { sender.balances(false)[''] }
      let(:fee) { 10_000 }
      let(:fee_estimator) { Glueby::Contract::FixedFeeEstimator.new(fixed_fee: fee) }

      before do
        process_block(to_address: sender.internal_wallet.receive_address)
        # create labeled utxo
        process_block(to_address: receiver.internal_wallet.receive_address('labeled'))
        before_balance
      end

      it 'pays TPC to another wallet' do
        Glueby::Contract::Payment.transfer(
          sender: sender,
          receiver_address: receiver.internal_wallet.receive_address,
          amount: 10_000,
          fee_estimator: fee_estimator
        )

        # sender lose sent amount and fee
        expect(sender.balances(false)['']).to eq(before_balance - (10_000 + fee))
        # receiver got the sent amount
        expect(receiver.balances(false)['']).to eq(10_000)
        # should not consume 'labeled' utxos
        expect(receiver.internal_wallet.list_unspent(false, 'labeled').size).to eq(1)
        expect(receiver.internal_wallet.list_unspent(false, 'labeled')[0][:amount]).to eq(5_000_000_000)
      end
    end

    context 'bear fees by UtxoProvider' do
      include_context 'setup fee provider'

      let!(:sender) { Glueby::Wallet.create }
      let!(:receiver) { Glueby::Wallet.create }
      let(:before_balance) { sender.balances(false)[''] }

      before do
        process_block(to_address: sender.internal_wallet.receive_address)
        # create labeled utxo
        process_block(to_address: receiver.internal_wallet.receive_address('labeled'))
        before_balance
      end

      it 'pays TPC to another wallet' do
        tx = Glueby::Contract::Payment.transfer(
          sender: sender,
          receiver_address: receiver.internal_wallet.receive_address,
          amount: 10_000
        )

        # sender lose just sent amount.
        expect(sender.balances(false)['']).to eq(before_balance - 10_000)
        # receiver got the sent amount
        expect(receiver.balances(false)['']).to eq(10_000)
        # should not consume 'labeled' utxos
        expect(receiver.internal_wallet.list_unspent(false, 'labeled').size).to eq(1)
        expect(receiver.internal_wallet.list_unspent(false, 'labeled')[0][:amount]).to eq(5_000_000_000)

        sighashtype = tx.inputs[-1].script_sig.chunks.first.pushed_data[-1].unpack1('C')
        expect(sighashtype).to eq(Tapyrus::SIGHASH_TYPE[:all])
      end
    end
  end
end
