RSpec.describe 'Token Contract', functional: true do
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
      let(:receiver) { Glueby::Wallet.create }
      let(:before_balance) { sender.balances(false)[''] }

      before do
        process_block(to_address: sender.internal_wallet.receive_address)
        process_block(to_address: receiver.internal_wallet.receive_address)
        before_balance
      end

      it 'reissunable token' do
        token, _txs = Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::REISSUABLE, amount: 10_000)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance - fee * 2)
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)

        token.transfer!(sender: sender, receiver_address: receiver.internal_wallet.receive_address, amount: 5_000)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance - fee * 3)
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(5_000)
        expect(receiver.balances(false)[token.color_id.to_hex]).to eq(5_000)

        token.reissue!(issuer: sender, amount: 5_000)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance - fee * 5)
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)

        token.burn!(sender: sender, amount: 10_000)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance - fee * 6)
        expect(sender.balances(false)[token.color_id.to_hex]).to be_nil
      end

      it 'non-reissunable token' do
        token, _txs = Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::NON_REISSUABLE, amount: 10_000)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance - fee * 1)
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)

        token.transfer!(sender: sender, receiver_address: receiver.internal_wallet.receive_address, amount: 5_000)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance - fee * 2)
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(5_000)
        expect(receiver.balances(false)[token.color_id.to_hex]).to eq(5_000)

        token.burn!(sender: sender, amount: 5_000)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance - fee * 3)
        expect(sender.balances(false)[token.color_id.to_hex]).to be_nil
      end

      it 'NFT token' do
        token, _txs = Glueby::Contract::Token.issue!(issuer: sender, token_type: Tapyrus::Color::TokenTypes::NFT)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance - fee * 1)
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(1)

        token.transfer!(sender: sender, receiver_address: receiver.internal_wallet.receive_address)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance - fee * 2)
        expect(sender.balances(false)[token.color_id.to_hex]).to be_nil
        expect(receiver.balances(false)[token.color_id.to_hex]).to eq 1

        token.burn!(sender: receiver, amount: 1)
        process_block

        expect(receiver.balances(false)[token.color_id.to_hex]).to be_nil
      end
    end

    context 'bear fees by UtxoProvider' do
      include_context 'setup fee provider'

      let(:fee) { 10_000 }
      let(:fee_estimator) { Glueby::Contract::FixedFeeEstimator.new(fixed_fee: fee) }
      let(:sender) { Glueby::Wallet.create }
      let(:receiver) { Glueby::Wallet.create }
      let(:before_balance) { sender.balances(false)[''] }
      let(:receiver_before_balance) { receiver.balances(false)[''] }

      before do
        process_block(to_address: sender.internal_wallet.receive_address)
        process_block(to_address: receiver.internal_wallet.receive_address)
        before_balance
        receiver_before_balance
      end

      it 'reissunable token' do
        token, _txs = Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::REISSUABLE, amount: 10_000)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance)
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)

        token.transfer!(sender: sender, receiver_address: receiver.internal_wallet.receive_address, amount: 5_000)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance)
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(5_000)
        expect(receiver.balances(false)[token.color_id.to_hex]).to eq(5_000)

        token.reissue!(issuer: sender, amount: 5_000)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance)
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)

        token.burn!(sender: sender, amount: 10_000)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance)
        expect(sender.balances(false)[token.color_id.to_hex]).to be_nil
      end

      it 'non-reissunable token' do
        token, _txs = Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::NON_REISSUABLE, amount: 10_000)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance)
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)

        token.transfer!(sender: sender, receiver_address: receiver.internal_wallet.receive_address, amount: 5_000)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance)
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(5_000)
        expect(receiver.balances(false)[token.color_id.to_hex]).to eq(5_000)

        token.burn!(sender: sender, amount: 5_000)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance)
        expect(sender.balances(false)[token.color_id.to_hex]).to be_nil
      end

      it 'NFT token' do
        token, _txs = Glueby::Contract::Token.issue!(issuer: sender, token_type: Tapyrus::Color::TokenTypes::NFT)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance)
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(1)

        token.transfer!(sender: sender, receiver_address: receiver.internal_wallet.receive_address)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance)
        expect(sender.balances(false)[token.color_id.to_hex]).to be_nil
        expect(receiver.balances(false)[token.color_id.to_hex]).to eq 1

        token.burn!(sender: receiver, amount: 1)
        process_block

        expect(receiver.balances(false)['']).to eq(receiver_before_balance)
        expect(receiver.balances(false)[token.color_id.to_hex]).to be_nil
      end
    end
  end
end