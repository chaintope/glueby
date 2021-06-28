RSpec.describe 'Glueby::Contract::Task::Timestamp', active_record: true do
  let(:rpc) { double('mock') }
  let(:response_getrawtransaction) do
    {
      "txid"=>"a01d8a6bf7bef5719ada2b7813c1ce4dabaf8eb4ff22791c67299526793b511c", 
      "hash"=>"12a4c3b28bb6b48299952283984616b8fdd728cb61bb04a49ab12b5c757dae9d", 
      "features"=>1, "size"=>128, "vsize"=>128, "weight"=>512, "locktime"=>0, 
      "vin"=>[{"txid"=>"0555c5af698db73ed6378d2ed3c71e45fc6a1dbbcf931a248a7c9221f1d3220c", "vout"=>0, "scriptSig"=>{"asm"=>"", "hex"=>""}, "sequence"=>4294967295}], 
      "vout"=>[
        {"value"=>"0.0", "n"=>0, "scriptPubKey"=>{"asm"=>"OP_RETURN 4bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459a", "hex"=>"6a204bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459a", "type"=>"nulldata"}}, 
        {"value"=>"0.9999", "n"=>1, "scriptPubKey"=>{"asm"=>"OP_DUP OP_HASH160 b0179f0d7d738a51cca26d54d50329cab60a8c13 OP_EQUALVERIFY OP_CHECKSIG", "hex"=>"76a914b0179f0d7d738a51cca26d54d50329cab60a8c1388ac", "reqSigs"=>1, "type"=>"pubkeyhash", "addresses"=>["1H46Dzw3DaeV4QKGYMhnNHY6zViHWcBp6w"]}}
      ],
      "blockhash" => "02d65a0e88f8427bff77cee0a0b90eeddab927ebfcaf8c57b9c57d2b95219a81",
      "confirmations" => 282,
      "time" => 1592471969,
      "blocktime" => 1592471969
    }
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

  before(:each) do
    allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)
    allow(rpc).to receive(:sendrawtransaction).and_return('a01d8a6bf7bef5719ada2b7813c1ce4dabaf8eb4ff22791c67299526793b511c')
    allow(rpc).to receive(:getrawtransaction).and_return(response_getrawtransaction)
    allow(Glueby::Wallet).to receive(:load).with("5f924e7e5daf624616f96b2f659938d7").and_return(wallet)
    allow(internal_wallet).to receive(:list_unspent).and_return(unspents)

    Glueby::Contract::AR::Timestamp.create(wallet_id: "5f924e7e5daf624616f96b2f659938d7" , content: "\xFF\xFF\xFF", prefix: "app")
  end

  describe '#create' do
    subject { Rake.application['glueby:contract:timestamp:create'].execute }

    it { expect { subject }.to change { Glueby::Contract::AR::Timestamp.first.status }.from("init").to("unconfirmed") }
  end
end
