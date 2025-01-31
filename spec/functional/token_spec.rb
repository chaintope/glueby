RSpec.describe 'Token Contract', functional: true, mysql: true do
  context 'bear fees by sender' do
    let(:fee) { 10_000 }
    let(:sender) { Glueby::Wallet.create }
    let(:receiver) { Glueby::Wallet.create }
    let(:before_balance) { sender.balances(false)[''] }

    before do
      process_block(to_address: sender.internal_wallet.receive_address)
      process_block(to_address: receiver.internal_wallet.receive_address)
      before_balance
    end

    shared_examples 'token contract works correctly bearing fees by sender' do
      it 'reissunable token' do
        expect(Glueby::Contract::AR::ReissuableToken.count).to eq(0)

        token, _txs = Glueby::Contract::Token.issue!(
          issuer: sender,
          token_type: Tapyrus::Color::TokenTypes::REISSUABLE,
          amount: 10_000,
          fee_estimator: fee_estimator
        )
        process_block

        if fee_estimator.is_a?(Glueby::Contract::FeeEstimator::Fixed)
          expect(sender.balances(false)['']).to eq(before_balance - fee * 2)
        end

        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)
        expect(Glueby::Contract::AR::ReissuableToken.count).to eq(1)

        token.transfer!(
          sender: sender,
          receiver_address: receiver.internal_wallet.receive_address,
          amount: 5_000,
          fee_estimator: fee_estimator
        )
        process_block

        if fee_estimator.is_a?(Glueby::Contract::FeeEstimator::Fixed)
          expect(sender.balances(false)['']).to eq(before_balance - fee * 3)
        end

        expect(sender.balances(false)[token.color_id.to_hex]).to eq(5_000)
        expect(receiver.balances(false)[token.color_id.to_hex]).to eq(5_000)

        token.reissue!(issuer: sender, amount: 5_000, fee_estimator: fee_estimator)
        process_block

        if fee_estimator.is_a?(Glueby::Contract::FeeEstimator::Fixed)
          expect(sender.balances(false)['']).to eq(before_balance - fee * 5)
        end
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)

        token.burn!(sender: sender, amount: 10_000, fee_estimator: fee_estimator)
        process_block

        if fee_estimator.is_a?(Glueby::Contract::FeeEstimator::Fixed)
          expect(sender.balances(false)['']).to eq(before_balance - fee * 6)
        end
        expect(sender.balances(false)[token.color_id.to_hex]).to be_nil

        # If the sending to Tapyrus Core is failure, Glueby::Contract::AR::ReissuableToken should not be created.
        TapyrusCoreContainer.stop
        begin
          Glueby::Contract::Token.issue!(
            issuer: sender,
            token_type: Tapyrus::Color::TokenTypes::REISSUABLE,
            amount: 10_000,
            fee_estimator: fee_estimator
          )
        rescue Errno::ECONNREFUSED, Errno::ECONNRESET
          # Ignored
        end
        expect(Glueby::Contract::AR::ReissuableToken.count).to eq(1)
      end

      it 'non-reissunable token' do
        token, _txs = Glueby::Contract::Token.issue!(
          issuer: sender,
          token_type: Tapyrus::Color::TokenTypes::NON_REISSUABLE,
          amount: 10_000,
          fee_estimator: fee_estimator
        )
        process_block

        if fee_estimator.is_a?(Glueby::Contract::FeeEstimator::Fixed)
          expect(sender.balances(false)['']).to eq(before_balance - fee * 1)
        end
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)

        token.transfer!(
          sender: sender,
          receiver_address: receiver.internal_wallet.receive_address,
          amount: 5_000,
          fee_estimator: fee_estimator
        )
        process_block

        if fee_estimator.is_a?(Glueby::Contract::FeeEstimator::Fixed)
          expect(sender.balances(false)['']).to eq(before_balance - fee * 2)
        end
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(5_000)
        expect(receiver.balances(false)[token.color_id.to_hex]).to eq(5_000)

        token.burn!(sender: sender, amount: 5_000, fee_estimator: fee_estimator)
        process_block

        if fee_estimator.is_a?(Glueby::Contract::FeeEstimator::Fixed)
          expect(sender.balances(false)['']).to eq(before_balance - fee * 3)
        end
        expect(sender.balances(false)[token.color_id.to_hex]).to be_nil
      end

      it 'NFT token' do
        token, _txs = Glueby::Contract::Token.issue!(
          issuer: sender,
          token_type: Tapyrus::Color::TokenTypes::NFT,
          fee_estimator: fee_estimator
        )
        process_block

        if fee_estimator.is_a?(Glueby::Contract::FeeEstimator::Fixed)
          expect(sender.balances(false)['']).to eq(before_balance - fee * 1)
        end
        expect(sender.balances(false)[token.color_id.to_hex]).to eq(1)

        token.transfer!(
          sender: sender,
          receiver_address: receiver.internal_wallet.receive_address,
          fee_estimator: fee_estimator
        )
        process_block

        if fee_estimator.is_a?(Glueby::Contract::FeeEstimator::Fixed)
          expect(sender.balances(false)['']).to eq(before_balance - fee * 2)
        end
        expect(sender.balances(false)[token.color_id.to_hex]).to be_nil
        expect(receiver.balances(false)[token.color_id.to_hex]).to eq 1

        receiver_before_balance = receiver.balances(false)['']

        token.burn!(sender: receiver, amount: 1, fee_estimator: fee_estimator)
        process_block

        if fee_estimator.is_a?(Glueby::Contract::FeeEstimator::Fixed)
          expect(receiver.balances(false)['']).to eq(receiver_before_balance - fee)
        end

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
            issuer: sender,
            token_type: Tapyrus::Color::TokenTypes::NON_REISSUABLE,
            amount: 10_000,
            fee_estimator: fee_estimator
          )

          if fee_estimator.is_a?(Glueby::Contract::FeeEstimator::Fixed)
            expect(sender.balances(false)['']).to eq(before_balance - fee * 1)
          end
          expect(sender.balances(false)[token.color_id.to_hex]).to eq(10_000)

          token.transfer!(
            sender: sender,
            receiver_address: receiver.internal_wallet.receive_address,
            amount: 5_000,
            fee_estimator: fee_estimator
          )

          if fee_estimator.is_a?(Glueby::Contract::FeeEstimator::Fixed)
            expect(sender.balances(false)['']).to eq(before_balance - fee * 2)
          end
          expect(sender.balances(false)[token.color_id.to_hex]).to eq(5_000)
          expect(receiver.balances(false)[token.color_id.to_hex]).to eq(5_000)

          token.burn!(sender: sender, amount: 5_000, fee_estimator: fee_estimator)

          if fee_estimator.is_a?(Glueby::Contract::FeeEstimator::Fixed)
            expect(sender.balances(false)['']).to eq(before_balance - fee * 3)
          end
          expect(sender.balances(false)[token.color_id.to_hex]).to be_nil
        end
      end
    end

    context 'fee estimator is Fixed' do
      it_behaves_like 'token contract works correctly bearing fees by sender' do
        let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new(fixed_fee: fee) }
      end
    end

    context 'fee estimator is Auto' do
      it_behaves_like 'token contract works correctly bearing fees by sender' do
        let(:fee_estimator) { Glueby::Contract::FeeEstimator::Auto.new }
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

    it 'doesn\'t raise insufficient error in too much split number' do
      expect do
        Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::REISSUABLE, amount: 10_000, split: 25)
      end.not_to raise_error
      expect(sender.balances(false)['']).to be_nil

      expect do
        Glueby::Contract::Token.issue!(
          issuer: sender, token_type: Tapyrus::Color::TokenTypes::NON_REISSUABLE, amount: 10_000, split: 25)
      end.not_to raise_error
      expect(sender.balances(false)['']).to be_nil
    end
  end

  context 'multi threading' do
    include_context 'setup utxo provider'
    let(:utxo_pool_size) { 40 }
    let(:utxo_provider) { Glueby::UtxoProvider.new }

    let(:sender) { Glueby::Wallet.create }
    let(:receiver) { Glueby::Wallet.create }
    let(:before_balance) { sender.balances(false)[''] }
    let(:count) { 20 }

    let(:issue_amount) { 100_000 }

    shared_examples 'issuing token works correctly' do
      def issue_on_multi_thread(count)
        on_multi_thread(count) do
          issue
        end
      end

      def issue
        token, _txs = Glueby::Contract::Token.issue!(
          issuer: sender,
          token_type: token_type,
          amount: issue_amount
        )
        token
      end

      it 'broadcast transactions with no error on multi thread' do
        expect(utxo_provider.current_utxo_pool_size).to eq utxo_pool_size
        tokens = issue_on_multi_thread(count)
        process_block

        expect(sender.balances(false)['']).to eq(before_balance)
        tokens.each do |token|
          expect(sender.balances(false)[token.color_id.to_hex]).to eq(issue_amount)
        end

        expect(utxo_provider.current_utxo_pool_size).to eq utxo_pool_size - count
      end

      context 'broadcasting funding tx is failure' do
        let(:count) { 1 }
        let(:rpc) { double('mock') }

        before do
          allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)
          allow(rpc).to receive(:sendrawtransaction).and_raise(Tapyrus::RPC::Error.new(
            '500',
            'Internal Server Error',
            { 'code' => -25, 'message' => 'Missing inputs'}))
        end

        it 'unlock UTXOs that are used as inputs' do
          expect { issue }.to raise_error(Tapyrus::RPC::Error)
          expect(Glueby::Internal::Wallet::AR::Utxo.where('locked_at is not null').count).to eq 0
        end
      end

      context 'broadcasting issuing tx is failure' do
        let(:count) { 1 }
        let(:rpc) { double('mock') }

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

        it 'unlock UTXOs that are used as inputs' do
          expect { issue }.to raise_error(Tapyrus::RPC::Error)
          expect(Glueby::Internal::Wallet::AR::Utxo.where('locked_at is not null').count).to eq 0
        end
      end
    end

    shared_examples 'transferring token works correctly' do
      let!(:token) do
        token, _tx = Glueby::Contract::Token.issue!(
          issuer: sender,
          token_type: Tapyrus::Color::TokenTypes::REISSUABLE,
          split: count,
          amount: issue_amount
        )

        Rake.application['glueby:utxo_provider:manage_utxo_pool'].execute
        process_block
        token
      end

      def transfer_on_multi_thread(count)
        on_multi_thread(count) do
          transfer(issue_amount / count)
        end
      end

      def transfer(amount)
        token.transfer!(
          sender: sender,
          receiver_address: receiver.internal_wallet.receive_address,
          amount: amount,
          fee_estimator: Glueby::Contract::FeeEstimator::Auto.new
        )
      end

      it 'broadcast transactions with no error on multi thread' do
        skip 'NFT cannot split to multiple UTXOs to transfer on multi thread.' if token_type == Tapyrus::Color::TokenTypes::NFT

        expect(utxo_provider.current_utxo_pool_size).to eq utxo_pool_size
        transfer_on_multi_thread(count)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(receiver.balances(false)[token.color_id.to_hex]).to eq(issue_amount)
        expect(utxo_provider.current_utxo_pool_size).to eq utxo_pool_size - count
      end

      context 'broadcasting is failure' do
        let(:count) { 1 }
        let(:rpc) { double('mock') }

        before do
          allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)
          allow(rpc).to receive(:sendrawtransaction).and_raise(Tapyrus::RPC::Error.new(
            '500',
            'Internal Server Error',
            { 'code' => -25, 'message' => 'Missing inputs'}))
        end

        it 'unlock UTXOs that are used as inputs' do
          expect { transfer(issue_amount) }.to raise_error(Tapyrus::RPC::Error)
          expect(Glueby::Internal::Wallet::AR::Utxo.where('locked_at is not null').count).to eq 0
        end
      end
    end

    shared_examples 'burning token works correctly' do
      let!(:token) do
        token, _tx = Glueby::Contract::Token.issue!(
          issuer: sender,
          token_type: Tapyrus::Color::TokenTypes::REISSUABLE,
          split: count,
          amount: issue_amount
        )

        Rake.application['glueby:utxo_provider:manage_utxo_pool'].execute
        process_block
        token
      end

      def burn_on_multi_thread(count)
        on_multi_thread(count) do
          burn(issue_amount / count)
        end
      end

      def burn(amount)
        token.burn!(
          sender: sender,
          amount: amount,
          fee_estimator: Glueby::Contract::FeeEstimator::Auto.new
        )
      end

      it 'broadcast transactions with no error on multi thread' do
        skip 'NFT cannot split to multiple UTXOs to burn on multi thread.' if token_type == Tapyrus::Color::TokenTypes::NFT

        expect(utxo_provider.current_utxo_pool_size).to eq utxo_pool_size
        burn_on_multi_thread(count)
        process_block

        expect(sender.balances(false)['']).to be_nil
        expect(sender.balances(false)[token.color_id.to_hex]).to be_nil
        expect(utxo_provider.current_utxo_pool_size).to eq utxo_pool_size - count
      end

      context 'broadcasting is failure' do
        let(:count) { 1 }
        let(:rpc) { double('mock') }

        before do
          allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)
          allow(rpc).to receive(:sendrawtransaction).and_raise(Tapyrus::RPC::Error.new(
            '500',
            'Internal Server Error',
            { 'code' => -25, 'message' => 'Missing inputs'}))
        end

        it 'unlock UTXOs that are used as inputs' do
          expect { burn(issue_amount) }.to raise_error(Tapyrus::RPC::Error)
          expect(Glueby::Internal::Wallet::AR::Utxo.where('locked_at is not null').count).to eq 0
        end
      end
    end

    context 'REISSUABLE token' do
      let(:token_type) { Tapyrus::Color::TokenTypes::REISSUABLE }

      it_behaves_like 'issuing token works correctly'
      it_behaves_like 'transferring token works correctly'
      it_behaves_like 'burning token works correctly'
    end

    context 'NON_REISSUABLE token' do
      let(:token_type) { Tapyrus::Color::TokenTypes::NON_REISSUABLE }

      it_behaves_like 'issuing token works correctly'
      it_behaves_like 'transferring token works correctly'
      it_behaves_like 'burning token works correctly'
    end

    context 'NFT token' do
      let(:token_type) { Tapyrus::Color::TokenTypes::NFT }
      let(:issue_amount) { 1 }

      it_behaves_like 'issuing token works correctly'
      it_behaves_like 'transferring token works correctly'
      it_behaves_like 'burning token works correctly'
    end
  end
end