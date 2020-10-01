require "bundler/setup"
require "glueby"
require "tapyrus"

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
  end

  config.after(:each) do |example|
    if example.metadata[:active_record]
      teardown_database
    end
  end
end

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
end

def teardown_database
  connection = ::ActiveRecord::Base.connection
  connection.drop_table :utxos, if_exists: true
  connection.drop_table :wallets, if_exists: true
  connection.drop_table :keys, if_exists: true
  connection.drop_table :timestamps, if_exists: true
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
    '0000000000000000000000000000000000000000000000000000000000000000'
  end
end
