require 'active_record'
require 'rake'

RSpec.describe 'Glueby::Contract::Task::WalletAdapter' do
  def setup_database
    ::ActiveRecord::Base.establish_connection(config)
    connection = ::ActiveRecord::Base.connection
    connection.create_table :wallets do |t|
      t.string :wallet_id
      t.timestamps
    end
    connection.add_index :wallets, [:wallet_id], unique: true

    connection.create_table :keys do |t|
      t.string     :private_key
      t.string     :public_key
      t.string     :script_pubkey
      t.integer    :purpose
      t.belongs_to :wallet, null: true
      t.timestamps
    end
    connection.add_index :keys, [:script_pubkey], unique: true
    connection.add_index :keys, [:private_key], unique: true

    connection.create_table :utxos do |t|
      t.string     :txid
      t.integer    :index
      t.bigint     :value
      t.string     :script_pubkey
      t.integer    :status
      t.belongs_to :key, null: true
      t.timestamps
    end
    connection.add_index :utxos, [:txid, :index], unique: true
  end

  before(:all) do
    @rake = setup_rake_task
  end

  before(:each) do
    allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)
    allow(rpc).to receive(:getblock).with('5498724b2d536c99b5a0533ebc2a5f00d59309cfe9f05e9a72a221343c240c5e', 0).and_return(response_getblock)
    allow(rpc).to receive(:getrawtransaction).with('3c345488060a07bae910fe0879e0c72927cb0283f6757d92cf0ac5609c409b17').and_return(response_getrawtransaction)

    setup_database

    wallet = Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF')
    private_key='206f3acb5b7ac66dacf87910bb0b04bed78284b9b50c0d061705a44447a947ff'
    Glueby::Internal::Wallet::AR::Key.create(private_key: private_key, purpose: :change, wallet: wallet)
  end

  after do
    connection = ::ActiveRecord::Base.connection
    connection.drop_table :utxos, if_exists: true
    connection.drop_table :wallets, if_exists: true
    connection.drop_table :keys, if_exists: true
  end

  def setup_rake_task
    Rake::Application.new.tap do |rake|
      Rake.application = rake
      Rake.application.rake_require 'tasks/glueby/contract/wallet_adapter'
      Rake::Task.define_task(:environment)
    end
  end

  let(:config) { { adapter: 'sqlite3', database: 'test' } }
  let(:rpc) { double('mock') }
  let(:response_getblock) do
    '01000000f5e01c832b49a073188a90a283e9f941483dd3b362ada3c69100a823' \
    '42df74027c9cfe8681330cea81115f6e008d2c1fd20a2dd47c942b11129ce3e2' \
    'b51656d2179b409c60c50acf927d75f68302cb2729c7e07908fe10e9ba070a06' \
    '8854343cca4c735f0040a34a233ca3b90837c81992df91a562ebf5fe00a31fe7' \
    'e4c39475b6ea9431cc46efabad5a7037e58992ceddd6dc6d483af39c40f5af64' \
    '4adeff10a5322c45f11201010000000100000000000000000000000000000000' \
    '000000000000000000000000000000000d000000035d0101ffffffff0100f205' \
    '2a010000001976a91457dd450aed53d4e35d3555a24ae7dbf3e08a78ec88ac00' \
    '000000'
  end
  let(:response_getrawtransaction) do
    '0100000001000000000000000000000000000000000000000000000000000000' \
    '00000000000d000000035d0101ffffffff0100f2052a010000001976a91457dd' \
    '450aed53d4e35d3555a24ae7dbf3e08a78ec88ac00000000'
  end

  describe '#import_block' do
    subject { @rake['glueby:contract:wallet_adapter:import_block'].invoke('5498724b2d536c99b5a0533ebc2a5f00d59309cfe9f05e9a72a221343c240c5e') }

    after { @rake['glueby:contract:wallet_adapter:import_block'].reenable }

    it do
      expect(rpc).to receive(:getrawtransaction).once
      subject
    end
    it { expect { subject }.to change { Glueby::Internal::Wallet::AR::Utxo.count }.from(0).to(1) }
  end

  describe '#import_tx' do
    subject { @rake['glueby:contract:wallet_adapter:import_tx'].invoke('3c345488060a07bae910fe0879e0c72927cb0283f6757d92cf0ac5609c409b17') }

    after { @rake['glueby:contract:wallet_adapter:import_tx'].reenable }

    it do
      expect(rpc).to receive(:getrawtransaction).once
      subject
    end
    it { expect { subject }.to change { Glueby::Internal::Wallet::AR::Utxo.count }.from(0).to(1) }
  end
end
