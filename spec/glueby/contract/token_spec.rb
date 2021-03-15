# frozen_string_literal: true

RSpec.describe 'Glueby::Contract::Token' do
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
  before do
    allow(internal_wallet).to receive(:list_unspent).and_return(unspents)
    allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)
    allow(rpc).to receive(:sendrawtransaction).and_return('')
  end

  describe '.issue!' do
    subject { Glueby::Contract::Token.issue!(issuer: issuer, token_type: token_type, amount: amount) }

    let(:issuer) { wallet }
    let(:token_type) { Tapyrus::Color::TokenTypes::REISSUABLE }
    let(:amount) { 1_000 }

    it { expect { subject }.not_to raise_error }
    it { expect(subject.color_id.type).to eq Tapyrus::Color::TokenTypes::REISSUABLE }

    context 'invalid amount' do
      let(:amount) { 0 }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InvalidAmount }
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
    subject { token.reissue!(issuer: issuer, amount: amount) }

    let(:token) { Glueby::Contract::Token.issue!(issuer: issuer) }
    let(:issuer) { wallet }
    let(:amount) { 1_000 }

    it { expect { subject }.not_to raise_error }

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
      let(:unspents) { [] }

      it { expect { subject }.to raise_error Glueby::Contract::Errors::InsufficientFunds }
    end
  end

  describe '#transfer!' do
    subject { token.transfer!(sender: sender, receiver_address: receiver_address, amount: amount) }

    let(:token) { Glueby::Contract::Token.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb376a914234113b860822e68f9715d1957af28b8f5117ee288ac'.htb) }
    let(:sender) { wallet }
    let(:receiver_address) { wallet.internal_wallet.receive_address }
    let(:amount) { 200_000 }

    it { expect { subject }.not_to raise_error }

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

  describe '#burn!' do
    subject { token.burn!(sender: sender, amount: amount) }

    let(:token) { Glueby::Contract::Token.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb376a914234113b860822e68f9715d1957af28b8f5117ee288ac'.htb) }
    let(:sender) { wallet }
    let(:amount) { 200_000 }

    it { expect { subject }.not_to raise_error }

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

  describe '#amount' do
    subject { token.amount(wallet: wallet) }

    let(:token) { Glueby::Contract::Token.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb376a914234113b860822e68f9715d1957af28b8f5117ee288ac'.htb) }

    it { is_expected.to eq 200_000 }
  end

  describe '#color_id' do
    subject { token.color_id.to_payload.bth }

    let(:token) { Glueby::Contract::Token.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb376a914234113b860822e68f9715d1957af28b8f5117ee288ac'.htb) }

    it { is_expected.to eq 'c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3' }

    context 'with no script pubkey' do
      let(:token) { Glueby::Contract::Token.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3'.htb) }

      it { is_expected.to eq 'c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3' }
    end
  end

  describe '#to_payload' do
    subject { token.to_payload.bth }

    let(:token) { Glueby::Contract::Token.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb376a914234113b860822e68f9715d1957af28b8f5117ee288ac'.htb) }

    it { is_expected.to eq 'c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb376a914234113b860822e68f9715d1957af28b8f5117ee288ac' }

    context 'with no script pubkey' do
      let(:token) { Glueby::Contract::Token.parse_from_payload('c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3'.htb) }

      it { is_expected.to eq 'c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3' }
    end
  end
end