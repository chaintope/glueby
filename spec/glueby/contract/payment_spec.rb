RSpec.describe 'Glueby::Contract::Payment', active_record: true do
  let(:wallet) { TestWallet.new(internal_wallet) }
  let(:internal_wallet) { TestInternalWallet.new }
  let(:unspents) do
    [
      {
        txid: '5c3d79041ff4974282b8ab72517d2ef15d8b6273cb80a01077145afb3d5e7cc5',
        script_pubkey: '76a914234113b860822e68f9715d1957af28b8f5117ee288ac',
        vout: 0,
        amount: 100_000_000,
        finalized: false
      }, {
        txid: 'd49c8038943d37c2723c9c7a1c4ea5c3738a9bad5827ddc41e144ba6aef36db',
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
        amount: 1,
        finalized: true
      }, {
        txid: 'f14b29639483da7c8d17b7b7515da4ff78b91b4b89434e7988ab1bc21ab41377',
        vout: 0,
        script_pubkey: '21c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016bc76a914fc688c091d91789ccda7a27bd8d88be9ae4af58e88ac',
        amount: 100_000,
        finalized: true
      }, {
        txid: '100c4dc65ea4af8abb9e345b3d4cdcc548bb5e1cdb1cb3042c840e147da72fa2',
        vout: 0,
        script_pubkey: '21c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3bc76a9144f15d2203821d7ea719314126b79bd1e530fc97588ac',
        amount: 100_000,
        finalized: true
      }, {
        txid: 'a3f20bc94c8d77c35ba1770116d2b34375475a4194d15f76442636e9f77d50d9',
        vout: 2,
        script_pubkey: '21c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3bc76a9144f15d2203821d7ea719314126b79bd1e530fc97588ac',
        amount: 100_000,
        finalized: true
      }
    ]
  end

  let(:rpc) { double('rpc') }
  before do
    allow(internal_wallet).to receive(:list_unspent).and_return(unspents)
    allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)
    allow(rpc).to receive(:sendrawtransaction).and_return('')
  end

  describe '#transfer' do
    subject { Glueby::Contract::Payment.transfer(sender: sender, receiver_address: receiver_address, amount: amount) }

    let(:sender) { wallet }
    let(:receiver_address) { wallet.internal_wallet.receive_address }
    let(:amount) { 200_000 }

    it { expect { subject }.not_to raise_error }

    it do
      allow(rpc).to receive(:sendrawtransaction) do |raw_transaction|
        tx = Tapyrus::Tx.parse_from_payload([raw_transaction].pack('H*'))

        expect(tx.outputs.count).to eq 2
        expect(tx.outputs[0].value).to eq 200_000
        expect(tx.outputs[1].value).to eq 99_790_000
      end

      subject
    end

    context 'use active record wallet' do
      before do
        Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new
        Glueby::Internal::Wallet::AR::Utxo.create(
          txid: '0000000000000000000000000000000000000000000000000000000000000000',
          index: 0,
          value: 100_000_000,
          script_pubkey: key1.to_p2pkh.to_hex,
          status: :finalized,
          key: key1
        )
      end

      let(:wallet_id) { 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF' }
      let(:key1) do 
        Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: wallet_id)
        wallet = Glueby::Internal::Wallet::AR::Wallet.find_by(wallet_id: wallet_id)
        wallet.keys.create(purpose: :receive) 
      end
      let(:sender) { Glueby::Wallet.load(wallet_id) }

      it do
        expect(Glueby::Internal::Wallet::AR::Utxo.count).to eq(1)
        expect(Glueby::Internal::Wallet::AR::Utxo.last.value).to eq(100_000_000)
        subject
        expect(Glueby::Internal::Wallet::AR::Utxo.count).to eq(1)
        expect(Glueby::Internal::Wallet::AR::Utxo.last.value).to eq(99_790_000)
      end
    end
    
    context 'invalid amount' do
      let(:amount) { 0 }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InvalidAmount }
    end

    context 'does not have enough tpc' do
      let(:amount) { 300_000 }
      let(:unspents) do
        [{
          txid: '864247cd4cae4b1f5bd3901be9f7a4ccba5bdea7db1d8bbd78b944da9cf39ef5',
          vout: 0,
          script_pubkey: '21c3eb2b846463430b7be9962843a97ee522e3dc0994a0f5e2fc0aa82e20e67fe893bc76a914bfeca7aed62174a7c60ebc63c7bd797bad46157a88ac',
          amount: 1,
          finalized: true
        }, {
          txid: 'f14b29639483da7c8d17b7b7515da4ff78b91b4b89434e7988ab1bc21ab41377',
          vout: 0,
          script_pubkey: '21c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016bc76a914fc688c091d91789ccda7a27bd8d88be9ae4af58e88ac',
          amount: 100_000,
          finalized: true
        }, {
          txid: '100c4dc65ea4af8abb9e345b3d4cdcc548bb5e1cdb1cb3042c840e147da72fa2',
          vout: 0,
          script_pubkey: '21c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3bc76a9144f15d2203821d7ea719314126b79bd1e530fc97588ac',
          amount: 100_000,
          finalized: true
        }, {
          txid: 'a3f20bc94c8d77c35ba1770116d2b34375475a4194d15f76442636e9f77d50d9',
          vout: 2,
          script_pubkey: '21c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3bc76a9144f15d2203821d7ea719314126b79bd1e530fc97588ac',
          amount: 100_000,
          finalized: true
        }]
      end

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InsufficientFunds }
    end

    context 'does not have enough tpc because the fee is too high' do
      subject { Glueby::Contract::Payment.transfer(sender: sender, receiver_address: receiver_address, amount: amount, fee_estimator: fee_estimator) }

      let(:fee_estimator) { Glueby::Contract::FixedFeeEstimator.new(fixed_fee: 1_000_000_000) }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InsufficientFunds }
    end
  end
end
