require 'active_record'
require 'rake'

def setup_database
  ::ActiveRecord::Base.establish_connection(config)
  connection = ::ActiveRecord::Base.connection
  connection.create_table :timestamps, force: true do |t|
    t.string   :txid
    t.integer  :status
    t.string   :content_hash
    t.string   :prefix
  end
end

def setup_rake_task
  Rake::Application.new.tap do |rake|
    Rake.application = rake
    Rake.application.rake_require 'tasks/tapyrus/contract/timestamp'
    Rake::Task.define_task(:environment)
  end
end

RSpec.describe 'Tapyrus::Contract::Task::Timestamp' do
  let(:rpc) { double('mock') }
  let(:response_listunspent) do
    [{
      'txid' => '0555c5af698db73ed6378d2ed3c71e45fc6a1dbbcf931a248a7c9221f1d3220c',
      'vout' => 0,
      'amount' => 1.00000000
    }, {
      'txid' => 'ac56a45f094f9d9e5af2f5f65e8e82e41db18f62646c53b1cefab081a60a11c7',
      'vout' => 0,
      'amount' => 1.00000000
    }]
  end
  let(:response_signrawtransactionwithwallet) do
    {
      'hex' => '01000000010c22d3f121927c8a241a93cfbb1d6afc451ec7d32e8d37d63eb78d69afc555050000000000ffffffff020000000000000000226a204bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459af0b9f505000000001976a914b0179f0d7d738a51cca26d54d50329cab60a8c1388ac00000000'
    }
  end
  let(:response_getrawtransaction) do
    {
      "txid"=>"a01d8a6bf7bef5719ada2b7813c1ce4dabaf8eb4ff22791c67299526793b511c", 
      "hash"=>"12a4c3b28bb6b48299952283984616b8fdd728cb61bb04a49ab12b5c757dae9d", 
      "features"=>1, "size"=>128, "vsize"=>128, "weight"=>512, "locktime"=>0, 
      "vin"=>[{"txid"=>"0555c5af698db73ed6378d2ed3c71e45fc6a1dbbcf931a248a7c9221f1d3220c", "vout"=>0, "scriptSig"=>{"asm"=>"", "hex"=>""}, "sequence"=>4294967295}], 
      "vout"=>[
        {"value"=>0.0, "n"=>0, "scriptPubKey"=>{"asm"=>"OP_RETURN 4bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459a", "hex"=>"6a204bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459a", "type"=>"nulldata"}}, 
        {"value"=>0.9999, "n"=>1, "scriptPubKey"=>{"asm"=>"OP_DUP OP_HASH160 b0179f0d7d738a51cca26d54d50329cab60a8c13 OP_EQUALVERIFY OP_CHECKSIG", "hex"=>"76a914b0179f0d7d738a51cca26d54d50329cab60a8c1388ac", "reqSigs"=>1, "type"=>"pubkeyhash", "addresses"=>["1H46Dzw3DaeV4QKGYMhnNHY6zViHWcBp6w"]}}
      ],
      "blockhash" => "02d65a0e88f8427bff77cee0a0b90eeddab927ebfcaf8c57b9c57d2b95219a81",
      "confirmations" => 282,
      "time" => 1592471969,
      "blocktime" => 1592471969
    }
  end

  let(:config) { { adapter: 'sqlite3', database: 'test' } }

  before(:all) do
    @rake = setup_rake_task
  end
  
  before(:each) do
    allow(Tapyrus::Contract::RPC).to receive(:client).and_return(rpc)
    allow(rpc).to receive(:listunspent).and_return(response_listunspent)
    allow(rpc).to receive(:signrawtransactionwithwallet).and_return(response_signrawtransactionwithwallet)
    allow(rpc).to receive(:sendrawtransaction).and_return('a01d8a6bf7bef5719ada2b7813c1ce4dabaf8eb4ff22791c67299526793b511c')
    allow(rpc).to receive(:getnewaddress).and_return('13L2GiUwB3HuyURm81ht6JiQAa8EcBN23H')
    allow(rpc).to receive(:getrawtransaction).and_return(response_getrawtransaction)

    setup_database
    Tapyrus::Contract::AR::Timestamp.create(content: "\xFF\xFF\xFF", prefix: "app")
  end

  after do
    connection = ::ActiveRecord::Base.connection
    connection.drop_table :timestamps, if_exists: true
  end

  describe '#create' do
    subject { @rake['tapyrus:contract:timestamp:create'].invoke }

    after { @rake['tapyrus:contract:timestamp:create'].reenable }

    it { expect { subject }.to change { Tapyrus::Contract::AR::Timestamp.first.status }.from("init").to("unconfirmed") }
  end

  describe '#confirm' do
    subject { @rake['tapyrus:contract:timestamp:confirm'].invoke }
    
    before { Tapyrus::Contract::AR::Timestamp.first.update(txid: 'a01d8a6bf7bef5719ada2b7813c1ce4dabaf8eb4ff22791c67299526793b511c', status: :unconfirmed) }

    after do
      @rake['tapyrus:contract:timestamp:create'].reenable
      @rake['tapyrus:contract:timestamp:confirm'].reenable
    end

    it { expect { subject }.to change { Tapyrus::Contract::AR::Timestamp.first.status }.from("unconfirmed").to("confirmed") }
  end
end