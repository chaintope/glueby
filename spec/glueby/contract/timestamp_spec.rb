RSpec.describe 'Glueby::Contract::Timestamp' do
  describe '#save!' do
    subject { contract.save! }

    let(:contract) do
      Glueby::Contract::Timestamp.new(
        content: "\01",
        prefix: ''
      )
    end
    let(:rpc) { double('mock') }
    let(:response_listunspent) do
      [{
        'txid' => '0555c5af698db73ed6378d2ed3c71e45fc6a1dbbcf931a248a7c9221f1d3220c',
        'vout' => 0,
        'amount' => 100000000
      }, {
        'txid' => 'ac56a45f094f9d9e5af2f5f65e8e82e41db18f62646c53b1cefab081a60a11c7',
        'vout' => 0,
        'amount' => 100000000
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
