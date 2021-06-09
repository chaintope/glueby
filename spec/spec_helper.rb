require "bundler/setup"
require "glueby"
require "tapyrus"
require 'rake'
require 'docker'
require 'active_record'

TAPYRUSD_CONTAINER_NAME = 'glueby-tapyrusd'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:each) do |example|
    if example.metadata[:active_record]
      setup_database
    end

    if example.metadata[:functional]
      Tapyrus.chain_params = :dev
      Glueby.configuration.rpc_config = { schema: 'http', host: '127.0.0.1', port: 12382, user: 'user', password: 'pass' }
      TapyrusCoreContainer.setup
      TapyrusCoreContainer.start
    end
  end

  config.after(:each) do |example|
    if example.metadata[:active_record]
      teardown_database
    end

    if example.metadata[:functional]
      Tapyrus.chain_params = :prod
      TapyrusCoreContainer.teardown
    end
  end

  config.before(:suite) do
    Rake::Application.new.tap do |rake|
      Rake.application = rake
      Rake.application.rake_require 'tasks/glueby/contract/timestamp'
      Rake.application.rake_require 'tasks/glueby/contract/wallet_adapter'
      Rake.application.rake_require 'tasks/glueby/contract/block_syncer'
      Rake::Task.define_task(:environment)
    end
  end
end

require_relative 'support/setup_fee_provider'

def setup_database
  config = { adapter: 'sqlite3', database: 'test' }
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

  connection.create_table :timestamps, force: true do |t|
    t.string   :txid
    t.integer  :status
    t.string   :content_hash
    t.string   :prefix
    t.string   :wallet_id
  end

  connection.create_table :system_informations, force: true do |t| 
    t.string  :info_key
    t.string  :info_value
    t.timestamps
  end
  connection.add_index  :system_informations, [:info_key], unique: true
  Glueby::AR::SystemInformation.create(info_key: 'synced_block_number', info_value: '0')

  connection.create_table :reissuable_tokens, force: true do |t|
    t.string :color_id, null: false
    t.string :script_pubkey, null: false
    t.timestamps
  end
  connection.add_index :reissuable_tokens, [:color_id], unique: true
end

def teardown_database
  connection = ::ActiveRecord::Base.connection
  connection.drop_table :utxos, if_exists: true
  connection.drop_table :wallets, if_exists: true
  connection.drop_table :keys, if_exists: true
  connection.drop_table :timestamps, if_exists: true
  connection.drop_table :system_informations, if_exists: true
  connection.drop_table :reissuable_tokens, if_exists: true
end

class TapyrusCoreContainer
  include Singleton

  class << self
    extend Forwardable
    delegate %i[setup start stop teardown] => :instance
  end

  attr_reader :container

  def setup
    Docker::Image.get('tapyrus/tapyrusd:edge')
    @container = Docker::Container.create({
      name: TAPYRUSD_CONTAINER_NAME,
      "Image"=>"tapyrus/tapyrusd:edge",
      "Env"=>[
        "GENESIS_BLOCK_WITH_SIG=0100000000000000000000000000000000000000000000000000000000000000000000002b5331139c6bc8646bb4e5737c51378133f70b9712b75548cb3c05f9188670e7440d295e7300c5640730c4634402a3e66fb5d921f76b48d8972a484cc0361e66ef74f45e012103af80b90d25145da28c583359beb47b21796b2fe1a23c1511e443e7a64dfdb27d40e05f064662d6b9acf65ae416379d82e11a9b78cdeb3a316d1057cd2780e3727f70a61f901d10acbe349cd11e04aa6b4351e782c44670aefbe138e99a5ce75ace01010000000100000000000000000000000000000000000000000000000000000000000000000000000000ffffffff0100f2052a010000001976a91445d405b9ed450fec89044f9b7a99a4ef6fe2cd3f88ac00000000"
      ],
      "HostConfig"=>{
        "Binds"=>["#{File.expand_path('support/tapyrus.conf', File.dirname(__FILE__))}:/etc/tapyrus/tapyrus.conf"],
        "PortBindings" => { "12381/tcp" => [{ "HostIp" => "", "HostPort" => "12382" }] },
      }
    })
  end

  def start
    container.start!

    # wait until core is ready
    begin
      Glueby::Internal::RPC.client.getblockchaininfo
    rescue Errno::ECONNRESET,
      Errno::EPIPE,
      EOFError,
      Tapyrus::RPC::Error,
      Errno::ECONNREFUSED
      retry
    end
  end

  def stop
    container.stop!
  end

  def teardown
    container = Docker::Container.get(TAPYRUSD_CONTAINER_NAME)
    container.stop!
    container.remove
  end
end

class TestWallet
  attr_reader :internal_wallet

  def initialize(internal_wallet)
    @internal_wallet = internal_wallet
  end
end

class TestInternalWallet < Glueby::Internal::Wallet
  def initialize; end

  def receive_address
    '1DBgMCNBdjQ1Ntz1vpwx2HMYJmc9kw88iT'
  end

  def list_unspent
    []
  end

  def change_address
    '1LUMPgobnSdbaA4iaikHKjCDLHveWYUSt5'
  end

  def sign_tx(tx, _prevtxs = [])
    tx
  end

  def broadcast(tx)
    tx
  end

  def get_addresses
    ['191arn68nSLRiNJXD8srnmw4bRykBkVv6o', '1DBgMCNBdjQ1Ntz1vpwx2HMYJmc9kw88iT']
  end
end

def setup_mock
  allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)
  allow(rpc).to receive(:getblock).with('022890167018b090211fb8ef26970c26a0cac6d29e5352f506dc31bbb84f3ce7', 0).and_return(response_getblock)
  allow(rpc).to receive(:getrawtransaction).with('2acb0d1015c382d63d4d8404b3219fc37c2c5c49aa6d6994f654758fb0179071').and_return(response_getrawtransaction1)
  allow(rpc).to receive(:getrawtransaction).with('b4d0dbafa6777d8a902cf4359bdf1bdca3dbaca9ad450f284530cf039f49a23b').and_return(response_getrawtransaction2)
  allow(rpc).to receive(:getblockcount).and_return(response_getblockcount)
  allow(rpc).to receive(:getblockhash).with(1).and_return(response_getblockhash)
  allow(rpc).to receive(:getblockhash).with(2).and_return(response_getblockhash)

  wallet = Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF')
    Glueby::Internal::Wallet::AR::Key.create(private_key: private_key, purpose: :change, wallet: wallet)

    # utxo for input
    Glueby::Internal::Wallet::AR::Utxo.create(
      txid: 'd176b97d76488de0a85609c359eba1ceb357e739c334aa93ed16eff1fd86c06e',
      index: 0,
      script_pubkey: '76a9143f90406e69facde1c8b08ddd9cf3d41f69ff2c3b88ac',
      value: 5_000_000_000,
      status: :finalized
    )
end

def setup_responses
  let(:rpc) { double('mock') }
  let(:config) { { adapter: 'sqlite3', database: 'test' } }
  let(:private_key) { 'ab2e2ba4c0605a3bd4f7734807e3346bae01290ebbaa0289c5c36912f7343650' }

  # This block has 2 transaction.
  # The first is coinbase to address 16o6NsMF5BmN35smQxjTjHjyecR2fRUSVF
  # The second is transfer TPC transaction 16o6NsMF5BmN35smQxjTjHjyecR2fRUSVF -> 16o6NsMF5BmN35smQxjTjHjyecR2fRUSVF
  let(:response_getblock) do
    '01000000953fec29387d5236e10fc3bd29dedafd0873551ec4cdfd0f9b07f020' \
    '34fc45514726f04b560e689db3a2dfc1d714720704e2c1b67909541ae4ae02a6' \
    'b4a0fa68e8ce7a8de5c1831a6543a1235a4a646fe9a5c0868623cc6d78249b62' \
    'd39979d69737745f00401d01200783805741e17c577f59fe14213872592eeab7' \
    '4a680fca45b9530ed8facb53666a6b481109532a1b8a2774776b2ab373ff87cf' \
    'c2538cd39cf7d984515602010000000100000000000000000000000000000000' \
    '000000000000000000000000000000001000000003600101ffffffff01101906' \
    '2a010000001976a9143f90406e69facde1c8b08ddd9cf3d41f69ff2c3b88ac00' \
    '00000001000000016ec086fdf1ef16ed93aa34c339e757b3cea1eb59c30956a8' \
    'e08d48767db976d1000000006a47304402207a484912d6878f694b7a3f8fafc3' \
    '271c3d961fd8c0bc14f1321cbdb153400a1a0220440da5c48982a072aa37f281' \
    '5959cac8b7a3d650dc47d497bb75d5ad124ae39601210261f487323a75d17cb8' \
    '6e9d745b8581afb8e98cb2b6151184bd12fd81c48fc167ffffffff01f0ca052a' \
    '010000001976a9143f90406e69facde1c8b08ddd9cf3d41f69ff2c3b88ac0000' \
    '0000' \
  end

  # coinbase
  let(:response_getrawtransaction1) do
    '0100000001000000000000000000000000000000000000000000000000000000' \
    '00000000001000000003600101ffffffff011019062a010000001976a9143f90' \
    '406e69facde1c8b08ddd9cf3d41f69ff2c3b88ac00000000'
  end

  # transfer TPC
  let(:response_getrawtransaction2) do
    '01000000016ec086fdf1ef16ed93aa34c339e757b3cea1eb59c30956a8e08d48' \
    '767db976d1000000006a47304402207a484912d6878f694b7a3f8fafc3271c3d' \
    '961fd8c0bc14f1321cbdb153400a1a0220440da5c48982a072aa37f2815959ca' \
    'c8b7a3d650dc47d497bb75d5ad124ae39601210261f487323a75d17cb86e9d74' \
    '5b8581afb8e98cb2b6151184bd12fd81c48fc167ffffffff01f0ca052a010000' \
    '001976a9143f90406e69facde1c8b08ddd9cf3d41f69ff2c3b88ac00000000'
  end
  let(:response_getblockcount) { 2 }
  let(:response_getblockhash) { '022890167018b090211fb8ef26970c26a0cac6d29e5352f506dc31bbb84f3ce7' }
end

def process_block(to_address: Tapyrus::Key.generate.to_p2pkh)
  Glueby::Internal::RPC.client.generatetoaddress(1, to_address, 'cUJN5RVzYWFoeY8rUztd47jzXCu1p57Ay8V7pqCzsBD3PEXN7Dd4')
  Rake.application['glueby:contract:block_syncer:start'].execute
end