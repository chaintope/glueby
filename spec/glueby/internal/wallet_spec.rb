RSpec.describe 'Glueby::Internal::Wallet' do
  class self::TestWalletAdapter < Glueby::Internal::Wallet::AbstractWalletAdapter
    def create_wallet(wallet_id = nil)
      wallet_id || 'created_wallet_id'
    end
    def load_wallet(wallet_id); end
  end

  before do
    Glueby::Internal::Wallet.wallet_adapter = self.class::TestWalletAdapter.new
  end

  after do
    Glueby::Internal::Wallet.wallet_adapter = nil
  end

  let(:wallet) { Glueby::Internal::Wallet.create }

  describe 'create' do
    subject { Glueby::Internal::Wallet.create }
    it { should be_a Glueby::Internal::Wallet }
    it 'has wallet id' do
      expect(subject.id).to eq 'created_wallet_id'
    end

    context 'wallet_id is specified' do
      subject { Glueby::Internal::Wallet.create('specified_wallet_id') }
      it { should be_a Glueby::Internal::Wallet }
      it 'has wallet id' do
        expect(subject.id).to eq 'specified_wallet_id'
      end
    end
  end

  describe 'load' do
    subject { Glueby::Internal::Wallet.load(wallet_id) }

    let(:wallet_id) { '0828d0ce8ff358cd0d7b19ac5c43c3bb' }

    it { expect(subject.id).to eq wallet_id }

    context 'if already loaded' do
      let(:error) { Glueby::Internal::Wallet::Errors::WalletAlreadyLoaded }

      it do
        allow(Glueby::Internal::Wallet.wallet_adapter).to receive(:load_wallet).and_raise(error)
        expect(subject.id).to eq wallet_id
      end
    end

    context 'if not initialized' do
      before { Glueby::Internal::Wallet.wallet_adapter = nil }

      it { expect { subject }.to raise_error(Glueby::Internal::Wallet::Errors::ShouldInitializeWalletAdapter) }
    end

    context 'if not exist' do
      let(:error) { Glueby::Internal::Wallet::Errors::WalletNotFound }

      it do
        allow(Glueby::Internal::Wallet.wallet_adapter).to receive(:load_wallet).and_raise(error)
        expect { subject }.to raise_error(Glueby::Internal::Wallet::Errors::WalletNotFound)
      end
    end
  end

  describe 'ShouldInitializeWalletAdapter Error' do
    before do
      Glueby::Internal::Wallet.wallet_adapter = nil
    end

    it 'should raise the error' do
      expect { Glueby::Internal::Wallet.create }.to raise_error(Glueby::Internal::Wallet::Errors::ShouldInitializeWalletAdapter)
    end

  end

  describe '.wallets', active_record: true do
    subject { Glueby::Internal::Wallet.wallets }

    context 'active record adapter' do
      before { Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new }
      it do
        wallet1 = Glueby::Internal::Wallet.create('00000000000000000000000000000001')
        wallet2 = Glueby::Internal::Wallet.create('00000000000000000000000000000003')
        wallet3 = Glueby::Internal::Wallet.create('00000000000000000000000000000002')

        expect(subject.count).to eq 3
        # Order by id
        expect(subject[0].id).to eq wallet1.id
        expect(subject[1].id).to eq wallet3.id
        expect(subject[2].id).to eq wallet2.id
      end
    end
  end

  describe 'broadcast' do
    let(:tx) { Tapyrus::Tx.new }

    context 'A block argument is given' do
      let(:block) { Proc.new {} }

      it 'pass the block to a wallet adapter' do
        expect(Glueby::Internal::Wallet.wallet_adapter)
          .to receive(:broadcast).with('created_wallet_id', tx) do |*args, &proc|
          expect(proc).to eq(block)
        end
        wallet.broadcast(tx, &block)
      end
    end

    context 'A block argument is not given' do
      it 'doesnt pass the block to a wallet adapter' do
        expect(Glueby::Internal::Wallet.wallet_adapter)
          .to receive(:broadcast).with('created_wallet_id', tx) do |*args, &proc|
          expect(proc).to be_nil
        end
        wallet.broadcast(tx)
      end
    end
  end

  shared_context 'unspents' do
    let(:unspents) do
      [
        {
          txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
          script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
          vout: 0,
          amount: 100_000_000,
          finalized: false
        },{
          txid: '1d49c8038943d37c2723c9c7a1c4ea5c3738a9bad5827ddc41e144ba6aef36db',
          script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
          vout: 1,
          amount: 100_000_000,
          finalized: true
        }, {
          txid: '1d49c8038943d37c2723c9c7a1c4ea5c3738a9bad5827ddc41e144ba6aef36db',
          script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
          vout: 2,
          amount: 50_000_000,
          finalized: true
        }, {
          txid: '864247cd4cae4b1f5bd3901be9f7a4ccba5bdea7db1d8bbd78b944da9cf39ef5',
          vout: 0,
          script_pubkey: '21c3eb2b846463430b7be9962843a97ee522e3dc0994a0f5e2fc0aa82e20e67fe893bc76a914bfeca7aed62174a7c60ebc63c7bd797bad46157a88ac',
          color_id: 'c3eb2b846463430b7be9962843a97ee522e3dc0994a0f5e2fc0aa82e20e67fe893',
          amount: 1,
          finalized: true
        }, {
          txid: 'f14b29639483da7c8d17b7b7515da4ff78b91b4b89434e7988ab1bc21ab41377',
          vout: 0,
          script_pubkey: '21c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016bc76a914fc688c091d91789ccda7a27bd8d88be9ae4af58e88ac',
          color_id: 'c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016',
          amount: 100_000,
          finalized: true
        }, {
          txid: '100c4dc65ea4af8abb9e345b3d4cdcc548bb5e1cdb1cb3042c840e147da72fa2',
          vout: 0,
          script_pubkey: '21c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3bc76a9144f15d2203821d7ea719314126b79bd1e530fc97588ac',
          color_id: 'c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3',
          amount: 100_000,
          finalized: true
        }, {
          txid: 'a3f20bc94c8d77c35ba1770116d2b34375475a4194d15f76442636e9f77d50d9',
          vout: 2,
          script_pubkey: '21c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3bc76a9144f15d2203821d7ea719314126b79bd1e530fc97588ac',
          color_id: 'c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3',
          amount: 100_000,
          finalized: true
        }
      ]
    end
    let(:finalized_unspents) { unspents.select{|i| i[:finalized]} }
  end

  describe 'collect_uncolored_outputs' do
    include_context 'unspents'
    before { allow(internal_wallet).to receive(:list_unspent).and_return(finalized_unspents) }

    subject do
      wallet.internal_wallet.collect_uncolored_outputs(
        amount,
        nil,
        only_finalized,
        shuffle,
        lock_utxos,
        excludes
      )
    end

    let(:amount) { 150_000_000 }
    let(:only_finalized) { true }
    let(:shuffle) { false }
    let(:lock_utxos) { false }
    let(:excludes) { [] }
    let(:wallet) { TestWallet.new(internal_wallet) }
    let(:internal_wallet) { TestInternalWallet.new }

    it { expect(subject[0]).to eq 150_000_000 }
    it { expect(subject[1].size).to eq 2 }

    context 'with unconfirmed' do
      let(:amount) { 250_000_000 }
      let(:only_finalized) { false }

      it do
        allow(internal_wallet).to receive(:list_unspent).with(Tapyrus::Color::ColorIdentifier.default, false, nil).and_return(unspents.select{ |u| !u[:color_id]})
        expect(subject[0]).to eq 250_000_000
        expect(subject[1].size).to eq 3
      end
    end

    context 'does not have enough tpc' do
      let(:amount) { 250_000_001 }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InsufficientFunds }
    end

    context 'amount is nil' do
      let(:amount) { nil }
      let(:only_finalized) { false }

      it 'returns one output' do
        allow(internal_wallet).to receive(:list_unspent).with(Tapyrus::Color::ColorIdentifier.default, false, nil).and_return(unspents.select{ |u| !u[:color_id]})
        expect(subject[0]).to eq 250_000_000
        expect(subject[1].size).to eq 3
      end
    end

    context 'lock_utxos is true' do
      let(:lock_utxos) { true }

      it '#lock_unspent should be called for each UTXOs' do
        allow(internal_wallet).to receive(:lock_unspent).with(unspents[1]).and_return(true)
        allow(internal_wallet).to receive(:lock_unspent).with(unspents[2]).and_return(true)
        subject
        expect(internal_wallet).to have_received(:lock_unspent).with(unspents[1])
        expect(internal_wallet).to have_received(:lock_unspent).with(unspents[2])
      end
    end

    context 'excludes is specified' do
      let(:excludes) { [unspents[1]] }
      let(:amount) { 50_000_000 }

      it 'returns except utxos that is includes the excludes' do
        expect(subject[0]).to eq(50_000_000)
        expect(subject[1].size).to eq(1)
        expect(subject[1]).to eq([unspents[2]])
      end
    end

    context 'it gets do .. end block' do
      subject do
        wallet.internal_wallet.collect_uncolored_outputs(
          amount,
          nil,
          only_finalized,
          shuffle,
          lock_utxos,
          excludes
        ) do |utxo|
          utxo[:amount] == 50_000_000
        end
      end

      let(:amount) { 50_000_000 }

      it 'returns a utxo that has 50_000_000 amount' do
        expect(subject[0]).to eq(50_000_000)
        expect(subject[1].size).to eq(1)
        expect(subject[1]).to eq([unspents[2]])
      end
    end
  end

  describe '#collect_colored_outputs' do
    include_context 'unspents'

    subject do
      wallet.internal_wallet.collect_colored_outputs(
        color_id,
        amount,
        label,
        only_finalized,
        shuffle,
        lock_utxos,
        excludes
      )
    end

    let(:wallet) { TestWallet.new(internal_wallet) }
    let(:internal_wallet) { TestInternalWallet.new }
    let(:color_id) { Tapyrus::Color::ColorIdentifier.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3'.htb) }
    let(:amount) { 1_000 }
    let(:label) { nil }
    let(:only_finalized) { false }
    let(:shuffle) { false }
    let(:lock_utxos) { false }
    let(:excludes) { [] }

    before do
      allow(internal_wallet).to receive(:list_unspent).and_return(unspents)
      allow(internal_wallet).to receive(:list_unspent).with(Tapyrus::Color::ColorIdentifier.default, false, nil).and_return(unspents.select{ |u| !u[:color_id]})
      allow(internal_wallet).to receive(:list_unspent).with(color_id, false, nil).and_return(unspents.select{ |u| u[:color_id] == color_id.to_hex })
    end

    it 'returns one output' do
      expect(subject[0]).to eq 100_000
      expect(subject[1].size).to eq 1
    end

    context 'it needs more amounts' do
      let(:amount) { 101_000 }

      it 'returns one output' do
        expect(subject[0]).to eq 200_000
        expect(subject[1].size).to eq 2
      end
    end

    context 'amount is negative' do
      let(:amount) { -1 }

      it 'returns one output' do
        expect { subject }.to raise_error Glueby::ArgumentError
      end
    end

    context 'does not have enough colored coin' do
      let(:amount) { 200_001 }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InsufficientTokens }
    end

    context 'amount is nil' do
      let(:amount) { nil }

      it 'returns one output' do
        expect(subject[0]).to eq 200_000
        expect(subject[1].size).to eq 2
      end
    end

    context 'lock_utxos is true' do
      let(:lock_utxos) { true }
      let(:amount) { 200_000 }

      it '#lock_unspent should be called for each UTXOs' do
        allow(internal_wallet).to receive(:lock_unspent).with(unspents[5]).and_return(true)
        allow(internal_wallet).to receive(:lock_unspent).with(unspents[6]).and_return(true)
        subject
        expect(internal_wallet).to have_received(:lock_unspent).with(unspents[5])
        expect(internal_wallet).to have_received(:lock_unspent).with(unspents[6])
      end
    end

    context 'excludes is specified' do
      let(:excludes) { [unspents[5]] }
      let(:amount) { 100_000 }

      it 'returns except utxos that is includes the excludes' do
        expect(subject[0]).to eq(100_000)
        expect(subject[1].size).to eq(1)
        expect(subject[1]).to eq([unspents[6]])
      end
    end

    context 'it gets do .. end block' do
      subject do
        wallet.internal_wallet.collect_colored_outputs(
          color_id,
          amount,
          nil,
          only_finalized,
          shuffle,
          lock_utxos,
          excludes
        ) do |utxo|
          utxo[:vout] == 2
        end
      end

      let(:amount) { 100_000 }

      it 'returns a utxo that has 100_000 amount' do
        expect(subject[0]).to eq(100_000)
        expect(subject[1].size).to eq(1)
        expect(subject[1]).to eq([unspents[6]])
      end
    end
  end

  describe '#fill_uncolored_inputs' do
    subject do
      internal_wallet.fill_uncolored_inputs(
        tx,
        target_amount: target_amount,
        current_amount: current_amount,
        fee_estimator: fee_estimator
      )
    end

    let(:internal_wallet) { TestInternalWallet.new }

    let(:tx) do
      tx = Tapyrus::Tx.new
      tx.outputs << Tapyrus::TxOut.new(value: 1_000, script_pubkey: Tapyrus::Script.to_p2pkh(Tapyrus::Key.generate.hash160))
      tx
    end
    let(:target_amount) { 1_000 }
    let(:current_amount) { 0 }

    context 'use FeeEstimator::Auto' do
      let(:fee_estimator) { Glueby::Contract::FeeEstimator::Auto.new }

      context 'the tx has no inputs' do
        let(:utxos) do
          2.times.to_a.map{ |i| { txid: "33a87aa53268376862076180bad5aa0542373dfde22d4b4d62dd7016c16fd5a2", vout: i, amount: 1_000 } }
        end

        it 'adds inputs' do
          allow(internal_wallet).to receive(:list_unspent).once.and_return(utxos)
          tx, fee, current_amount, provided_utxos = subject
          expect(tx.inputs.size).to eq(2)
          expect(fee).to eq(360)
          expect(current_amount).to eq(2_000)
          expect(provided_utxos).to contain_exactly(*utxos)
        end
      end

      context 'the tx already has enough TPC amount in inputs' do
        let(:target_amount) { 1_000 }
        let(:current_amount) { 2_000 }

        before do
          tx.inputs << Tapyrus::TxIn.new(out_point: Tapyrus::OutPoint.from_txid('33a87aa53268376862076180bad5aa0542373dfde22d4b4d62dd7016c16fd5a2', 0))
        end

        it 'doesn\'t add inputs' do
          tx, fee, current_amount, provided_utxos = subject
          expect(tx.inputs.size).to eq(1)
          expect(fee).to eq(219)
          expect(current_amount).to eq(2_000)
          expect(provided_utxos).to be_empty
        end
      end

      context 'the tx already has an TPC input' do
        let(:target_amount) { 1_000 }
        let(:current_amount) { 1_000 }

        let(:utxos) do
          [{ txid: "33a87aa53268376862076180bad5aa0542373dfde22d4b4d62dd7016c16fd5a2", vout: 0, amount: 1_000 }]
        end

        before do
          tx.inputs << Tapyrus::TxIn.new(out_point: Tapyrus::OutPoint.from_txid('33a87aa53268376862076180bad5aa0542373dfde22d4b4d62dd7016c16fd5a2', 1))
        end

        it 'adds inputs' do
          allow(internal_wallet).to receive(:list_unspent).once.and_return(utxos)
          tx, fee, current_amount, provided_utxos = subject
          expect(tx.inputs.size).to eq(2)
          expect(fee).to eq(360)
          expect(current_amount).to eq(2_000)
          expect(provided_utxos).to contain_exactly(*utxos)
        end
      end

      context 'by adding inputs, the fee will increase and insufficient' do
        let(:target_amount) { 10_000 }
        let(:utxos) do
          12.times.to_a.map{ |i| { txid: "33a87aa53268376862076180bad5aa0542373dfde22d4b4d62dd7016c16fd5a2", vout: i, amount: 1_000 } }
        end

        it 'adds inputs' do
          expect(internal_wallet).to receive(:list_unspent).twice.and_return(utxos)
          tx, fee, current_amount, provided_utxos = subject
          expect(tx.inputs.size).to eq(12)
          expect(fee).to eq(1_770)
          expect(current_amount).to eq(12_000)
          expect(provided_utxos).to contain_exactly(*utxos)
        end
      end
    end
  end

  describe "#get_addresses_info" do
    subject { Glueby::Internal::Wallet.get_addresses_info(addresses) }

    let(:addresses) { ['15JL32ZJTEeNUT7Fs348errZ8xmavXXhLp'] }

    it "call WalletAdapter.get_addresses_info" do
      allow(Glueby::Internal::Wallet.wallet_adapter).to receive(:get_addresses_info)

      subject

      expect(Glueby::Internal::Wallet.wallet_adapter).to have_received(:get_addresses_info).with(addresses)
    end
  end

  describe "#delete" do
    subject { wallet.delete }

    it "call WalletAdapter#delete" do
      allow(Glueby::Internal::Wallet.wallet_adapter).to receive(:delete_wallet)

      subject

      expect(Glueby::Internal::Wallet.wallet_adapter).to have_received(:delete_wallet).with(wallet.id)
    end
  end

  describe "#create_pubkey" do
    subject { wallet.create_pubkey }

    it "call WalletAdapter#create_pubkey" do
      allow(Glueby::Internal::Wallet.wallet_adapter).to receive(:create_pubkey)

      subject

      expect(Glueby::Internal::Wallet.wallet_adapter).to have_received(:create_pubkey).with(wallet.id)
    end
  end

  describe "#pay_to_contract_key" do
    subject { wallet.pay_to_contract_key(payment_base, contents) }

    let(:payment_base) { "02046e89be90d26872e1318feb7d5ca7a6f588118e76f4906cf5b8ef262b63ab49" }
    let(:contents) { "010203040506"}

    it "call WalletAdapter#pay_to_contract_key" do
      allow(Glueby::Internal::Wallet.wallet_adapter).to receive(:pay_to_contract_key)

      subject

      expect(Glueby::Internal::Wallet.wallet_adapter).to have_received(:pay_to_contract_key).with(wallet.id, payment_base, contents)
    end
  end

  describe "#list_unspent_with_count" do
    subject { wallet.list_unspent_with_count(color_id) }

    let(:color_id) { Tapyrus::Color::ColorIdentifier.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3'.htb) }

    it "call WalletAdapter#list_unspent_with_count" do
      allow(Glueby::Internal::Wallet.wallet_adapter).to receive(:list_unspent_with_count)

      subject

      expect(Glueby::Internal::Wallet.wallet_adapter).to have_received(:list_unspent_with_count).with(wallet.id, color_id, true, nil, 1, 25)
    end
  end
end