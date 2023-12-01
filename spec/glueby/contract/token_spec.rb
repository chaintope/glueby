# frozen_string_literal: true

RSpec.describe 'Glueby::Contract::Token', active_record: true do
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

  let(:rpc) { double('rpc') }

  shared_context 'use utxo provider' do
    let(:provider_key) do
      wallet = Glueby::Internal::Wallet::AR::Wallet.find_by(wallet_id: Glueby::UtxoProvider::WALLET_ID)
      wallet.keys.create(purpose: :receive)
    end
    let(:utxos) { 20 }

    before do
      Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new
      Glueby.configuration.enable_utxo_provider!
      Glueby::UtxoProvider.new

      # 20 Utxos are pooled.
      (0...utxos).each do |i|
        Glueby::Internal::Wallet::AR::Utxo.create(
          txid: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          index: i,
          script_pubkey: '76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
          key: provider_key,
          value: 1_000,
          status: :finalized
        )
      end
    end
    after { Glueby.configuration.disable_utxo_provider! }
  end

  before do
    allow(internal_wallet).to receive(:list_unspent).and_return([])
    allow(internal_wallet).to receive(:list_unspent).with(true, nil, color_id: Tapyrus::Color::ColorIdentifier.default).and_return(unspents.select{ |i| !i[:color_id] && i[:finalized] })
    allow(internal_wallet).to receive(:list_unspent).with(false, nil, color_id: Tapyrus::Color::ColorIdentifier.default).and_return(unspents.select{ |i| !i[:color_id] })
    [
      "c3eb2b846463430b7be9962843a97ee522e3dc0994a0f5e2fc0aa82e20e67fe893",
      "c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016",
      "c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3",
    ].each do |color_id_hex|
      color_id = Tapyrus::Color::ColorIdentifier.parse_from_payload(color_id_hex.htb)
      allow(internal_wallet).to receive(:list_unspent).with(true, nil, color_id: color_id).and_return(unspents.select{ |i| i[:color_id] == color_id_hex && i[:finalized] })
      allow(internal_wallet).to receive(:list_unspent).with(false, nil, color_id: color_id).and_return(unspents.select{ |i| i[:color_id] == color_id_hex })
    end
    allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)
    allow(rpc).to receive(:sendrawtransaction).and_return('')
  end

  describe '.issue!' do
    subject { Glueby::Contract::Token.issue!(issuer: issuer, token_type: token_type, amount: amount, split: split, metadata: metadata) }

    let(:issuer) { wallet }
    let(:token_type) { Tapyrus::Color::TokenTypes::REISSUABLE }
    let(:amount) { 1_000 }
    let(:split) { 1 }
    let(:metadata) { nil }
    
    shared_examples 'when metadata is included, p2c address should be generated' do
      context 'include metadata' do
        let(:metadata) { 'metadata' }
        let(:wallet) { Glueby::Wallet.create }
        let(:key) do
          ar_wallet = Glueby::Internal::Wallet::AR::Wallet.find_by(wallet_id: wallet.id)
          ar_wallet.keys.create(purpose: :receive)
        end
        let(:utxos) { 21 } # pool size of UtxoProvider

        before do
          Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new
          Glueby::Internal::Wallet::AR::Utxo.create(
            txid: '0000000000000000000000000000000000000000000000000000000000000000',
            index: 0,
            script_pubkey: '76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
            key: key,
            value: 100_000,
            status: :finalized
          )
        end

        it 'create metadata' do
          expect { subject }.to change(Glueby::Contract::AR::TokenMetadata, :count).by(1)
        end

        it 'send tpc to p2c_address' do
          token, txs = subject
          metadata = Glueby::Contract::AR::TokenMetadata.last
          expect(txs[0].outputs[0].script_pubkey.to_addr).to eq metadata.p2c_address
        end

        context 'failed to broadcast tx' do
          before do
            first = true
            allow(rpc).to receive(:sendrawtransaction) do |raw|
              if first
                first = false
                '11' * 32 # txid for funding transaction
              else
                # failed to broadcast issue transaction
                raise RuntimeError
              end
            end
          end

          it 'does not create metadata' do
            expect { subject }.to raise_error(RuntimeError)
              .and change(Glueby::Contract::AR::TokenMetadata, :count).by(0)
              .and change { Glueby::Internal::Wallet::AR::Utxo.where(status: :finalized).count }.by(-1 * used_utxos)
          end
        end
      end
    end

    context 'reissuable token' do
      it do
        expect {subject}.not_to raise_error
        expect(subject[0].color_id.type).to eq Tapyrus::Color::TokenTypes::REISSUABLE
        expect(subject[0].color_id.valid?).to be true
        expect(subject[1][1].valid?).to be true
        expect(Glueby::Contract::AR::ReissuableToken.count).to eq 1 
        expect(subject[0].color_id.to_hex).to eq Glueby::Contract::AR::ReissuableToken.find(1).color_id
        expect(subject[1][0].outputs.first.script_pubkey.to_hex).to eq Glueby::Contract::AR::ReissuableToken.find_by(color_id: subject[0].color_id.to_hex).script_pubkey
      end

      it_behaves_like 'when metadata is included, p2c address should be generated' do
        let(:used_utxos) { 1 }
      end

      context 'use utxo provider', active_record: true do
        include_context 'use utxo provider'

        it 'create funding tx and issuance tx' do
          expect(subject[1].size).to eq 2
          expect(subject[1][0].outputs.first.value).to eq 10_000 # FUNDING_TX_AMOUNT
          expect(subject[1][1].outputs.first.value).to eq 1_000 # Colored coin
        end

        it_behaves_like 'when metadata is included, p2c address should be generated' do
          let(:used_utxos) { 20 }
        end
      end
    end

    context 'non reissuable token' do 
      let(:token_type) { Tapyrus::Color::TokenTypes::NON_REISSUABLE }
      it do
        expect {subject}.not_to raise_error
        expect(subject[0].color_id.type).to eq Tapyrus::Color::TokenTypes::NON_REISSUABLE
        expect(subject[0].color_id.valid?).to be true
        expect(subject[1].size).to eq 1 # Create issuance tx only.
        expect(subject[1][0].valid?).to be true
        expect(Glueby::Contract::AR::ReissuableToken.count).to eq 0
      end

      it_behaves_like 'when metadata is included, p2c address should be generated' do
        let(:used_utxos) { 1 }
      end

      context 'use utxo provider', active_record: true do
        include_context 'use utxo provider'

        it 'create funding tx and issuance tx' do
          expect(subject[1].size).to eq 2
          expect(subject[1][0].outputs.first.value).to eq 10_000 # FUNDING_TX_AMOUNT
          expect(subject[1][1].outputs.first.value).to eq 1_000 # Colored coin
        end

        it_behaves_like 'when metadata is included, p2c address should be generated' do
          let(:used_utxos) { 20 }
        end
      end
    end

    context 'nft' do
      let(:token_type) { Tapyrus::Color::TokenTypes::NFT }
      it do
        expect {subject}.not_to raise_error
        expect(subject[0].color_id.type).to eq Tapyrus::Color::TokenTypes::NFT
        expect(subject[0].color_id.valid?).to be true
        expect(subject[1].size).to eq 1 # Create issuance tx only.
        expect(subject[1][0].valid?).to be true
        expect(subject[1][0].outputs.first.value).to be 1
        expect(Glueby::Contract::AR::ReissuableToken.count).to eq 0
      end

      it_behaves_like 'when metadata is included, p2c address should be generated' do
        let(:used_utxos) { 1 }
      end

      context 'use utxo provider', active_record: true do
        include_context 'use utxo provider'

        it 'create funding tx and issuance tx' do
          expect(subject[1].size).to eq 2
          expect(subject[1][0].outputs.first.value).to eq 10_000 # FUNDING_TX_AMOUNT
          expect(subject[1][1].outputs.first.value).to eq 1 # Colored coin
        end

        it_behaves_like 'when metadata is included, p2c address should be generated' do
          let(:used_utxos) { 20 }
        end
      end
    end

    context 'invalid amount' do
      let(:amount) { 0 }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InvalidAmount }
    end

    context 'invalid split' do
      let(:split) { 2 }
      let(:token_type) { Tapyrus::Color::TokenTypes::NFT }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InvalidSplit }
    end

    context 'unsupported type' do
      let(:token_type) { 0x99 }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::UnsupportedTokenType }
    end

    context 'does not have enough tpc' do
      let(:unspents) { [] }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InsufficientFunds }
    end
  end

  describe '#reissue!' do
    subject { token[0].reissue!(issuer: issuer, amount: amount) }

    let(:token) { Glueby::Contract::Token.issue!(issuer: issuer) }
    let(:issuer) { Glueby::Wallet.create }
    let(:amount) { 1_000 }
    let(:key) do
      ar_wallet = Glueby::Internal::Wallet::AR::Wallet.find_by(wallet_id: issuer.id)
      ar_wallet.keys.create(purpose: :receive)
    end

    before do
      Glueby::Internal::Wallet.wallet_adapter = Glueby::Internal::Wallet::ActiveRecordWalletAdapter.new
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000001',
        index: 0,
        script_pubkey: '76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
        key: key,
        value: 100_000,
        status: :finalized
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000001',
        index: 1,
        script_pubkey: '76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
        key: key,
        value: 100_000,
        status: :finalized
      )
    end

    it { 
      expect { subject }.not_to raise_error
      expect(subject[0].valid?).to be true
      expect(subject[1].valid?).to be true
    }

    context 'when metadata exists' do
      let(:token) { Glueby::Contract::Token.issue!(issuer: issuer, metadata: 'metadata') }

      it do
        expect { subject }.not_to raise_error
        expect(subject[0].valid?).to be_truthy
        expect(subject[1].valid?).to be_truthy
      end
    end

    context 'use utxo provider', active_record: true do
      include_context 'use utxo provider'

      let(:utxos) { 42 }

      it do
        expect { subject }.not_to raise_error
        expect(subject[0].valid?).to be true
        expect(subject[1].valid?).to be true
      end
    end

    context 'invalid amount' do
      let(:amount) { 0 }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InvalidAmount }
    end

    context 'token is non reissuable' do
      let(:token) { Glueby::Contract::Token.issue!(issuer: issuer, token_type: Tapyrus::Color::TokenTypes::NON_REISSUABLE) }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InvalidTokenType }
    end

    context 'token is nft' do
      let(:token) { Glueby::Contract::Token.issue!(issuer: issuer, token_type: Tapyrus::Color::TokenTypes::NFT) }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InvalidTokenType }
    end

    context 'does not have enough tpc' do
      before { Glueby::Internal::Wallet::AR::Utxo.destroy_all }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InsufficientFunds }
    end

    context 'invalid reissuer' do
      subject { token[0].reissue!(issuer: reissuer, amount: amount) }

      let(:reissuer) { Glueby::Wallet.create }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::UnknownScriptPubkey }
    end

    context 'invalid color id' do
      let(:token) { [Glueby::Contract::Token.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb376'.htb)] }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::UnknownScriptPubkey }
    end
  end

  describe '#transfer!' do
    subject { token.transfer!(sender: sender, receiver_address: receiver_address, amount: amount) }

    let(:token) { Glueby::Contract::Token.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb376a914234113b860822e68f9715d1957af28b8f5117ee288ac'.htb) }
    let(:sender) { wallet }
    let(:receiver_address) { wallet.internal_wallet.receive_address }
    let(:amount) { 200_000 }

    it { 
      expect { subject }.not_to raise_error
      expect(subject[0].valid?).to be true
      expect(subject[1].valid?).to be true
    }

    context 'use utxo provider', active_record: true do
      include_context 'use utxo provider'

      it do
        expect(internal_wallet).to receive(:broadcast).once
        subject
      end
    end

    context 'invalid amount' do
      let(:amount) { 0 }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InvalidAmount }
    end

    context 'does not have enough token' do
      let(:amount) { 200_001 }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InsufficientTokens }
    end

    context 'does not have enough tpc' do
      let(:unspents) do
        [{
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
        }]
      end

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InsufficientFunds }
    end
  end

  describe '#multi_transfer!' do
    subject { token.multi_transfer!(sender: sender, receivers: receivers) }

    let(:receivers) do
      [
        {
          address: receiver_address, amount: amount
        },{
          address: another_address, amount: 1
        }
      ]
    end
    let(:token) { Glueby::Contract::Token.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb376a914234113b860822e68f9715d1957af28b8f5117ee288ac'.htb) }
    let(:sender) { wallet }
    let(:receiver_address) { wallet.internal_wallet.receive_address }
    let(:another_address) { wallet.internal_wallet.receive_address }
    let(:amount) { 199_999 }

    it { 
      expect { subject }.not_to raise_error
      expect(subject[0].valid?).to be true
      expect(subject[1].valid?).to be true
    }

    context 'use utxo provider', active_record: true do
      include_context 'use utxo provider'

      it do
        expect(internal_wallet).to receive(:broadcast).once
        subject
      end
    end

    context 'invalid amount' do
      let(:amount) { 0 }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InvalidAmount }
    end

    context 'does not have enough token' do
      let(:amount) { 200_000 }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InsufficientTokens }
    end

    context 'does not have enough tpc' do
      let(:unspents) do
        [{
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
        }]
      end

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InsufficientFunds }
    end
  end

  describe '#burn!' do
    subject { token.burn!(sender: sender, amount: amount, fee_estimator: fee_estimator) }

    let(:token) { Glueby::Contract::Token.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb376a914234113b860822e68f9715d1957af28b8f5117ee288ac'.htb) }
    let(:sender) { wallet }
    let(:amount) { 200_000 }
    let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new(fixed_fee: 455) }

    before do
      allow(sender).to receive(:balances).and_return({ 'c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3' => 200_000 })
    end

    it { expect { subject }.not_to raise_error }

    context 'use utxo provider', active_record: true do
      include_context 'use utxo provider'
      let(:amount) { 50_000 }
      let(:utxos) { 25 }

      it do
        expect(internal_wallet).to receive(:broadcast).once do |tx|
          # 1 colored input(100_000 token), 1 uncolored inputs(1_000 tapyrus)
          # Fee is 455 tapyrus, so 545 tapyrus is change. But the change amount is less than 546, so the change
          # output is not created. 545 tapyrus is also pay as fee.
          expect(tx.inputs.count).to eq(2)
          expect(tx.outputs.count).to eq(1)
          expect(tx.outputs[0].value).to eq(50_000)
        end
        subject
      end

      context 'burns all the amount the wallet have' do
        let(:amount) { 200_000 }

        it 'has one output for to be a standard tx' do
          expect(internal_wallet).to receive(:broadcast).once do |tx|
            # Inputs: 2 colored input(200_000 token), 1 uncolored inputs(1_000 tapyrus)
            # Outputs: 1 OP_RETURN output.
            # It never create TPC change output because of the change(that is 545) is less than dust threshold(546
            # tapyrus for the output).
            expect(tx.inputs.count).to eq(3)
            expect(tx.outputs.count).to eq(1)
            expect(tx.outputs[0].value).to eq(0)
            expect(tx.outputs[0].script_pubkey.op_return?).to be_truthy
          end
          subject
        end
      end

      context 'If the token amount and fee is equal to value in utxos' do
        let(:amount) { 100_000 }
        let(:fee_estimator) { Glueby::Contract::FeeEstimator::Fixed.new(fixed_fee: 455) }

        it 'has one output for to be a standard tx' do
          expect(internal_wallet).to receive(:broadcast).once do |tx|
            # It funds 1_000 tapyrus to the TX and fee is 455 tapyrus. So the rest 545 tapyrus is change amount.
            # But less than dust threshold(546 tapyrus for the output) can not be output value because of Tapyrus
            # Core's dust output policy. So, here will not create change output. All the remain TPC will be payed as fee.
            # And the TX has dummy output that has 0 value and OP_RETURN script.
            expect(tx.inputs.count).to eq(2)
            expect(tx.outputs.count).to eq(1)
            expect(tx.outputs[0].value).to eq(0)
            expect(tx.outputs[0].script_pubkey.op_return?).to be_truthy
          end
          subject
        end
      end

      context 'use Auto fee estimator' do
        let(:fee_estimator) { Glueby::Contract::FeeEstimator::Auto.new }

        it do
          expect(internal_wallet).to receive(:broadcast).once do |tx|
            # 1 colored input(100_000 token), 1 uncolored inputs(1_000 tapyrus)
            expect(tx.inputs.count).to eq 2
            expect(tx.outputs.count).to eq(2)
            expect(tx.outputs[0].value).to eq(50_000)
            # dummy tx size is 396
            expect(tx.outputs[1].value).to eq(604)
          end
          subject
        end
      end
    end

    context 'invalid amount' do
      let(:amount) { 0 }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InvalidAmount }
    end

    context 'does not have enough token' do
      let(:amount) { 200_001 }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InsufficientTokens }
    end

    context 'does not have enough tpc' do
      let(:unspents) do
        [{
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
        }]
      end

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InsufficientFunds }
    end

    context 'burns all the amount the wallet have' do
      let(:amount) { 200_000 }

      it 'has one output' do
        burn_tx = nil
        expect(internal_wallet).to receive(:broadcast) do |tx|
          burn_tx = tx
          tx
        end
        subject

        expect(burn_tx.outputs.count).to eq(1)
      end
    end
  end

  describe '#amount' do
    subject { token.amount(wallet: wallet) }

    let(:token) { Glueby::Contract::Token.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb376a914234113b860822e68f9715d1957af28b8f5117ee288ac'.htb) }

    let(:unspents) do
      [
        {
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
    it { is_expected.to eq 200_000 }

    context 'use unconfirmed utxo' do
      before do
        Glueby::AR::SystemInformation.create(
          info_key: 'use_only_finalized_utxo',
          info_value: '0'
        )
      end
      let(:unspents) do
        [
          {
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
          }, {
            txid: 'a3f20bc94c8d77c35ba1770116d2b34375475a4194d15f76442636e9f77d50d9',
            vout: 3,
            script_pubkey: '21c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3bc76a9144f15d2203821d7ea719314126b79bd1e530fc97588ac',
            color_id: 'c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3',
            amount: 100_000,
            finalized: false
          }
        ]
      end
      it { is_expected.to eq 300_000 }
    end
  end

  describe '#metadata', active_record: true do
    include_context 'use utxo provider'
    let(:utxos) { 21 }

    subject { token.metadata }

    let(:token) do
      Glueby::Contract::Token.issue!(
        issuer: issuer,
        token_type: Tapyrus::Color::TokenTypes::REISSUABLE,
        amount: 1_000,
        metadata: 'metadata'
      )[0]
    end
    let(:issuer) { Glueby::Wallet.create }

    it { is_expected.to eq 'metadata' }
    it 'access db only once' do
      allow(Glueby::Contract::AR::TokenMetadata).to receive(:find_by)
      subject
      subject
      expect(Glueby::Contract::AR::TokenMetadata).to have_received(:find_by).once
    end
  end

  describe '#p2c_address', active_record: true do
    include_context 'use utxo provider'
    let(:utxos) { 21 }

    subject { token.p2c_address }

    let(:token) do
      Glueby::Contract::Token.issue!(
        issuer: issuer,
        token_type: Tapyrus::Color::TokenTypes::REISSUABLE,
        amount: 1_000,
        metadata: 'metadata'
      )[0]
    end
    let(:issuer) { Glueby::Wallet.create }

    it { is_expected.not_to be_nil }
    it 'access db only once' do
      allow(Glueby::Contract::AR::TokenMetadata).to receive(:find_by)
      subject
      subject
      expect(Glueby::Contract::AR::TokenMetadata).to have_received(:find_by).once
    end
  end

  describe '#payment_base', active_record: true do
    include_context 'use utxo provider'
    let(:utxos) { 21 }

    subject { token.payment_base }

    let(:token) do
      Glueby::Contract::Token.issue!(
        issuer: issuer,
        token_type: Tapyrus::Color::TokenTypes::REISSUABLE,
        amount: 1_000,
        metadata: 'metadata'
      )[0]
    end
    let(:issuer) { Glueby::Wallet.create }

    it { is_expected.not_to be_nil }
    it 'access db only once' do
      allow(Glueby::Contract::AR::TokenMetadata).to receive(:find_by)
      subject
      subject
      expect(Glueby::Contract::AR::TokenMetadata).to have_received(:find_by).once
    end
  end

  describe '#color_id' do
    subject { token.color_id.to_payload.bth }

    let(:token) { Glueby::Contract::Token.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb376a914234113b860822e68f9715d1957af28b8f5117ee288ac'.htb) }

    it { is_expected.to eq 'c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3' }

    context 'with no script pubkey' do
      let(:token) { Glueby::Contract::Token.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3'.htb) }

      it { expect { subject }.to raise_error(Glueby::ArgumentError, 'script_pubkey should not be empty') }
    end
  end

  describe '#to_payload' do
    subject { token.to_payload.bth }

    let(:token) { Glueby::Contract::Token.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb376a914234113b860822e68f9715d1957af28b8f5117ee288ac'.htb) }

    it do
      expect(subject).to eq 'c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb376a914234113b860822e68f9715d1957af28b8f5117ee288ac'
      expect(Glueby::Contract::AR::ReissuableToken.count).to eq 1
    end

    context 'with no script pubkey' do
      let(:token) { Glueby::Contract::Token.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3'.htb) }

      it do
        expect{ subject } .to raise_error(Glueby::ArgumentError, 'script_pubkey should not be empty')
        expect(Glueby::Contract::AR::ReissuableToken.count).to eq 0
      end
    end
  end
end