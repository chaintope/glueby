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

        # Specify split option
        # It allow to split up to 24. If it set over 24, it raises the min relay fee error.
        # It uses Fixed fee strategy and the strategy estimate the fee to fixed amount but here it is insufficient to split to much outputs.
        token2, _txs = Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::REISSUABLE, amount: 10_000, split: 24)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token2.color_id.to_hex]).to eq(10_000)

        # Specify split option with FeeEstimator::Auto. It allow to split over 26.
        token3, _txs = Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::REISSUABLE, amount: 10_000, split: 100,
          fee_estimator: Glueby::Contract::FeeEstimator::Auto.new)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token3.color_id.to_hex]).to eq(10_000)

        # Specify metadata option
        token4, _txs = Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::REISSUABLE,
          amount: 10_000,
          fee_estimator: Glueby::Contract::FeeEstimator::Auto.new,
          metadata: 'metadata'
        )
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token4.color_id.to_hex]).to eq(10_000)

        token.transfer!(sender: sender, receiver_address: receiver.internal_wallet.receive_address, amount: 5_000)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(5_000)
        expect(receiver.balances(false)['']).to be_nil
        expect(receiver.balances(false)[token.color_id.to_hex]).to eq(5_000)

        token.reissue!(issuer: sender, amount: 5_000)
        process_block

        token3.reissue!(issuer: sender, amount: 10_000, split: 100, fee_estimator: Glueby::Contract::FeeEstimator::Auto.new)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)

        token.burn!(sender: sender, amount: 10_000)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token.color_id.to_hex]).to be_nil

        token4.reissue!(issuer: sender, amount: 10_000, fee_estimator: Glueby::Contract::FeeEstimator::Auto.new)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token4.color_id.to_hex]).to eq(20_000)
      end

      it 'non-reissunable token' do
        token, _txs = Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::NON_REISSUABLE, amount: 10_000)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)

        token2, _txs = Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::NON_REISSUABLE, amount: 10_000, split: 100,
          fee_estimator: Glueby::Contract::FeeEstimator::Auto.new)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token2.color_id.to_hex]).to eq(10_000)
        expect(sender.internal_wallet.list_unspent(false).select {|i| i[:color_id] == token2.color_id.to_hex}.size).to eq(100)

        # Specify metadata option
        token3, _txs = Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::NON_REISSUABLE,
          amount: 10_000,
          fee_estimator: Glueby::Contract::FeeEstimator::Auto.new,
          metadata: 'metadata'
        )
        process_block
        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token3.color_id.to_hex]).to eq(10_000)

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

        # Specify metadata option
        token2, _txs = Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::NFT,
          fee_estimator: Glueby::Contract::FeeEstimator::Auto.new,
          metadata: 'metadata'
        )
        process_block
        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token2.color_id.to_hex]).to eq(1)

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

      it 'multiple transfer' do
        token, _txs = Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::REISSUABLE, amount: 10_000)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)

        receivers = 100.times.map { { address: receiver.internal_wallet.receive_address, amount: 100 } }
        token.multi_transfer!(sender: sender, receivers: receivers, fee_estimator: Glueby::Contract::FeeEstimator::Auto.new)

        expect(sender.balances(false)[token.color_id.to_hex]).to be_nil
        expect(receiver.balances(false)[token.color_id.to_hex]).to eq(10_000)
        expect(receiver.internal_wallet.list_unspent(false).select {|i| i[:color_id] == token.color_id.to_hex}.size).to eq(100)
      end

      it 'raise insufficient error in to much split number' do
        expect do
          Glueby::Contract::Token.issue!(
            issuer: sender, token_type: Tapyrus::Color::TokenTypes::REISSUABLE, amount: 10_000, split: 25)
        end.to raise_error(
          Tapyrus::RPC::Error,
          '{"response_code":"500","response_msg":"Internal Server Error","rpc_error":{"code":-26,"message":"min relay fee not met, 2000 \u003c 2051 (code 66)"}}'
        )
        # It remains the amount of funding tx to sender's wallet
        expect(sender.balances(false)['']).to eq(2000)

        expect do
          Glueby::Contract::Token.issue!(
            issuer: sender, token_type: Tapyrus::Color::TokenTypes::NON_REISSUABLE, amount: 10_000, split: 25)
        end.to raise_error(
          Tapyrus::RPC::Error,
          '{"response_code":"500","response_msg":"Internal Server Error","rpc_error":{"code":-26,"message":"min relay fee not met, 2000 \u003c 2051 (code 66)"}}'
        )
        # It remains the amount of funding tx to sender's wallet
        expect(sender.balances(false)['']).to eq(4000)
      end
    end
  end

  context 'use mysql', mysql: true do
    include_context 'setup utxo provider'
    let(:utxo_pool_size) { 40 }

    let(:sender) { Glueby::Wallet.create }
    let(:receiver) { Glueby::Wallet.create }
    let(:before_balance) { sender.balances(false)[''] }
    let(:count) { 20 }

    def issue_on_multi_thread(count)
      threads = count.times.map do |i|
        Thread.new do
          token, _txs = Glueby::Contract::Token.issue!(
            issuer: sender,
            token_type: Tapyrus::Color::TokenTypes::REISSUABLE,
            amount: 10_000
          )
          token
        end
      end
      # Each value is Token object
      threads.map { |t| t.value }
    end

    it 'broadast transactions with no error on multi thread' do
      expect(Glueby::UtxoProvider.instance.current_utxo_pool_size).to eq utxo_pool_size
      tokens = issue_on_multi_thread(count)
      process_block

      expect(sender.balances(false)['']).to eq(before_balance)
      tokens.each do |token|
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)
      end

      expect(Glueby::UtxoProvider.instance.current_utxo_pool_size).to eq utxo_pool_size - count
    end
  end
end