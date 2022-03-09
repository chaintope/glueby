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
      let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new(fixed_fee: fee) }
      let(:sender) { Glueby::Wallet.create }
      let(:receiver) { Glueby::Wallet.create }
      let(:before_balance) { sender.balances(false)[''] }

      before do
        process_block(to_address: sender.internal_wallet.receive_address)
        process_block(to_address: receiver.internal_wallet.receive_address)
        before_balance
      end

      it 'reissunable token' do
        expect(Glueby::Contract::AR::ReissuableToken.count).to eq(0)

        token, _txs = Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::REISSUABLE, amount: 10_000)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance - fee * 2)
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)
        expect(Glueby::Contract::AR::ReissuableToken.count).to eq(1)

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

        # If the sending to Tapyrus Core is failure, Glueby::Contract::AR::ReissuableToken should not be created.
        TapyrusCoreContainer.stop
        begin
          Glueby::Contract::Token.issue!(
            issuer: sender, token_type: Tapyrus::Color::TokenTypes::REISSUABLE, amount: 10_000)
        rescue Errno::ECONNREFUSED
          # Ignored
        end
        expect(Glueby::Contract::AR::ReissuableToken.count).to eq(1)
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

      context 'transfer unconfirmed token' do
        before do
          Glueby::AR::SystemInformation.create(
            info_key: 'use_only_finalized_utxo',
            info_value: '0'
          )
        end
        it do
          token, _txs = Glueby::Contract::Token.issue!(
            issuer: sender, token_type: Tapyrus::Color::TokenTypes::NON_REISSUABLE, amount: 10_000)

          expect(sender.balances(false)['']).to eq(before_balance - fee * 1)
          expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)

          token.transfer!(sender: sender, receiver_address: receiver.internal_wallet.receive_address, amount: 5_000)

          expect(sender.balances(false)['']).to eq(before_balance - fee * 2)
          expect(sender.balances(false)[token.color_id.to_hex]).to eq(5_000)
          expect(receiver.balances(false)[token.color_id.to_hex]).to eq(5_000)

          token.burn!(sender: sender, amount: 5_000)

          expect(sender.balances(false)['']).to eq(before_balance - fee * 3)
          expect(sender.balances(false)[token.color_id.to_hex]).to be_nil
        end
      end
    end

    context 'bear fees by FeeProvider' do
      include_context 'setup fee provider'

      let(:fee) { 10_000 }
      let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new(fixed_fee: fee) }
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

    context 'UtxoProvider provides UTXOs' do
      include_context 'setup utxo provider'

      let(:sender) { Glueby::Wallet.create }
      let(:receiver) { Glueby::Wallet.create }

      it 'reissunable token' do
        token, _txs = Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::REISSUABLE, amount: 10_000)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)

        token.transfer!(sender: sender, receiver_address: receiver.internal_wallet.receive_address, amount: 5_000)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(5_000)
        expect(receiver.balances(false)['']).to be_nil
        expect(receiver.balances(false)[token.color_id.to_hex]).to eq(5_000)

        token.reissue!(issuer: sender, amount: 5_000)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)

        token.burn!(sender: sender, amount: 10_000)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token.color_id.to_hex]).to be_nil
      end

      it 'non-reissunable token' do
        token, _txs = Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::NON_REISSUABLE, amount: 10_000)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)

        token.transfer!(sender: sender, receiver_address: receiver.internal_wallet.receive_address, amount: 5_000)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(5_000)
        expect(receiver.balances(false)[token.color_id.to_hex]).to eq(5_000)

        token.burn!(sender: sender, amount: 5_000)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token.color_id.to_hex]).to be_nil
      end

      it 'NFT token' do
        token, _txs = Glueby::Contract::Token.issue!(issuer: sender, token_type: Tapyrus::Color::TokenTypes::NFT)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(1)

        token.transfer!(sender: sender, receiver_address: receiver.internal_wallet.receive_address)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token.color_id.to_hex]).to be_nil
        expect(receiver.balances(false)[token.color_id.to_hex]).to eq 1

        token.burn!(sender: receiver, amount: 1)
        process_block

        expect(receiver.balances(false)['']).to be_nil
        expect(receiver.balances(false)[token.color_id.to_hex]).to be_nil
      end
    end
  end
end