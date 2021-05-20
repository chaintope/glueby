# frozen_string_literal: true

RSpec.describe 'Glueby::Wallet' do
  class TestWalletAdapter < Glueby::Internal::Wallet::AbstractWalletAdapter
    def create_wallet(wallet_id = nil); end
    def list_unspent(wallet_id, only_finalized = true)
      utxos = [
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
          txid: '01480aea6f1233e620645f9eaec27e606a795fec07840ed38a0542335a596495',
          vout: 0,
          script_pubkey: '21c1de5b53145f480cf431c9697b197eb97da57dee816d068e572a20ebcc1b9cf6eabc76a914bd1025c40a785f3063cbee910c2e2eedcade666d88ac',
          color_id: 'c1de5b53145f480cf431c9697b197eb97da57dee816d068e572a20ebcc1b9cf6ea',
          amount: 100,
          finalized: false
        }, {
          txid: '0e8b3689982a00a1b9711ce1c558ab45face3051eb4adbb8d8113f23caacc8dd',
          vout: 0,
          script_pubkey: '21c14362a2e9fb5fa2da041d6a60d474cdc24218b2183855a22b7b20344f618c3ecebc76a914b377a81d3ab345b34c6da8530636a498bdd176cb88ac',
          color_id: 'c14362a2e9fb5fa2da041d6a60d474cdc24218b2183855a22b7b20344f618c3ece',
          amount: 10_000,
          finalized: false
        }
      ]

      if only_finalized == true 
        utxos.select { |utxo| utxo[:finalized] == true }
      else
        utxos
      end
    end
  end

  before { Glueby::Internal::Wallet.wallet_adapter = TestWalletAdapter.new }
  after { Glueby::Internal::Wallet.wallet_adapter = nil }

  describe '#balances' do
    subject { wallet.balances(only_finalized) }

    let(:wallet) { Glueby::Wallet.create }

    context 'only_finalized: true' do 
      let(:only_finalized) {true}
      let(:expected) do
        {
          '' => 150_000_000,
          'c3eb2b846463430b7be9962843a97ee522e3dc0994a0f5e2fc0aa82e20e67fe893' => 1,
          'c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016' => 100_000,
          'c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3' => 200_000
        }
      end

      it { is_expected.to eq expected }
    end

    context 'only_finalized: false' do
      let(:only_finalized) {false}
      let(:expected) do
        {
          '' => 150_000_000, 
          'c3eb2b846463430b7be9962843a97ee522e3dc0994a0f5e2fc0aa82e20e67fe893' => 1,
          'c2dbbebb191128de429084246fa3215f7ccc36d6abde62984eb5a42b1f2253a016' => 100_000,
          'c150ad685ec8638543b2356cb1071cf834fb1c84f5fa3a71699c3ed7167dfcdbb3' => 200_000,
          'c1de5b53145f480cf431c9697b197eb97da57dee816d068e572a20ebcc1b9cf6ea' => 100,
          'c14362a2e9fb5fa2da041d6a60d474cdc24218b2183855a22b7b20344f618c3ece' => 10_000
        }
      end

      it { is_expected.to eq expected }
    end
  end
end