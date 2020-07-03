RSpec.describe 'Glueby::Contract::TxBuilder' do
  class Mock
    include Glueby::Contract::TxBuilder
  end

  let(:mock) { Mock.new }
  let(:response) do
    [{
      'txid' => '0555c5af698db73ed6378d2ed3c71e45fc6a1dbbcf931a248a7c9221f1d3220c',
      'vout' => 0,
      'amount' => 1.00000000
    }, {
      'txid' => 'ac56a45f094f9d9e5af2f5f65e8e82e41db18f62646c53b1cefab081a60a11c7',
      'vout' => 0,
      'amount' => 1.00000000
    }, {
      'txid' => '266cf0f9dd234deb68f6c7fc2f733b6ce3fc02ae43ffa80a7374014c9609f460',
      'vout' => 4,
      'amount' => 1.00000000
    }]
  end

  describe '#collect_outputs' do
    subject(:outputs) { Mock.new.collect_outputs(response, amount) }

    let(:amount) { 110_000_000 }

    it { expect(outputs[0]).to eq 200_000_000 }
    it { expect(outputs[1].length).to eq 2 }
    it { expect(outputs[1][0]['txid']).to eq '0555c5af698db73ed6378d2ed3c71e45fc6a1dbbcf931a248a7c9221f1d3220c' }
    it { expect(outputs[1][1]['txid']).to eq 'ac56a45f094f9d9e5af2f5f65e8e82e41db18f62646c53b1cefab081a60a11c7' }

    context 'when sum of all outputs is less than specified amount' do
      let(:amount) { 300_000_001 }

      it { expect { subject }.to raise_error(Glueby::Contract::Errors::InsufficientFunds) }
    end
  end

  describe '#fill_input' do
    subject(:tx) { Mock.new.fill_input(transaction, outputs) }

    let(:transaction) { Tapyrus::Tx.new }
    let(:outputs) { response }

    it { expect(tx.inputs.length).to eq 3 }
  end

  describe '#fill_change_output' do
    subject(:tx) { Mock.new.fill_change_output(transaction, fee, pubkey, sum) }

    let(:outputs) { response }
    let(:transaction) do
      Tapyrus::Tx.new.tap do |t|
        t.outputs << Tapyrus::TxOut.new(value: 50_000_000, script_pubkey: Tapyrus::Script.new)
        t.outputs << Tapyrus::TxOut.new(value: 40_000_000, script_pubkey: Tapyrus::Script.new)
      end
    end
    let(:pubkey) { '034bf0d34293b2183c8e877c6fb38b000521df94eba21d72e6da621cb6a1d2b0e5' }
    let(:sum) { 200_000_000 }
    let(:fee) { 10_000 }

    it { expect(tx.outputs.length).to eq 3 }
    it { expect(tx.outputs.last.value).to eq 109_990_000 }
  end
end
