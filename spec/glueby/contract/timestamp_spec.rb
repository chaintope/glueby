RSpec.describe 'Glueby::Contract::Timestamp' do
  describe '#save!' do
    subject { contract.save! }

    let(:contract) do
      Glueby::Contract::Timestamp.new(
        wallet: wallet,
        content: "\01",
        prefix: ''
      )
    end
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
    let(:rpc) { double('mock') }
    let(:response_listunspent) do
      [{
        'txid' => '0555c5af698db73ed6378d2ed3c71e45fc6a1dbbcf931a248a7c9221f1d3220c',
        'vout' => 0,
        'amount' => '1.00000000'
      }, {
        'txid' => 'ac56a45f094f9d9e5af2f5f65e8e82e41db18f62646c53b1cefab081a60a11c7',
        'vout' => 0,
        'amount' => '1.00000000'
      }]
    end

    let(:response_signrawtransactionwithwallet) do
      {
        'hex' => '01000000010c22d3f121927c8a241a93cfbb1d6afc451ec7d32e8d37d63eb78d69afc555050000000000ffffffff020000000000000000226a204bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459af0b9f505000000001976a914b0179f0d7d738a51cca26d54d50329cab60a8c1388ac00000000'
      }
    end

    before do
      allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)
      allow(rpc).to receive(:listunspent).and_return(response_listunspent)
      allow(rpc).to receive(:signrawtransactionwithwallet).and_return(response_signrawtransactionwithwallet)
      allow(rpc).to receive(:sendrawtransaction).and_return('a01d8a6bf7bef5719ada2b7813c1ce4dabaf8eb4ff22791c67299526793b511c')
      allow(rpc).to receive(:getnewaddress).and_return('13L2GiUwB3HuyURm81ht6JiQAa8EcBN23H')
      allow(internal_wallet).to receive(:list_unspent).and_return(unspents)
    end

    it { expect(subject).to eq 'a01d8a6bf7bef5719ada2b7813c1ce4dabaf8eb4ff22791c67299526793b511c' }
    it 'create transaction' do
      subject
      expect(contract.tx.inputs.size).to eq 1
      expect(contract.tx.outputs.size).to eq 2
      expect(contract.tx.outputs[0].value).to eq 0
      expect(contract.tx.outputs[0].script_pubkey.op_return?).to be_truthy
      expect(contract.tx.outputs[0].script_pubkey.op_return_data.bth).to eq "4bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459a"
      expect(contract.tx.outputs[1].value).to eq 99_990_000
    end

    context 'if already broadcasted' do
      before { contract.save! }

      it { expect { subject }.to raise_error(Glueby::Contract::Errors::TxAlreadyBroadcasted) }
    end
  end
end
