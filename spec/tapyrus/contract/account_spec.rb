require 'active_record'
require 'rake'

def setup_account_database
  ::ActiveRecord::Base.establish_connection({
    adapter: 'sqlite3',
    database: 'test'
  })
  connection = ::ActiveRecord::Base.connection
  connection.create_table :accounts, force: true do |t|
    t.string :name
  end
  connection.create_table :addresses, force: true do |t|
    t.references :account, null: false
    t.boolean :change, null: false, default: false
    t.integer :address_index, null: false
    t.string :pubkey, null: false, index: true
    t.index [:account_id, :change, :address_index], unique: true
  end
end

RSpec.describe 'Tapyrus::Contract::Account' do
  before do
    setup_account_database
    Tapyrus::Contract::Account.set_master_key(seed: master_key.seed)
  end

  let(:master_key) { Tapyrus::Wallet::MasterKey.generate }

  describe 'self.set_master_key' do
    it 'set master_key by seed and mnemonic' do
      Tapyrus::Contract::Account.set_master_key(seed: master_key.seed)
      expect(Tapyrus::Contract::Account.master_key.seed).to eq master_key.seed

      Tapyrus::Contract::Account.set_master_key(mnemonic: master_key.mnemonic.join(' '))
      expect(Tapyrus::Contract::Account.master_key.seed).to eq master_key.seed
    end
  end

  describe 'self.create!' do
    subject { Tapyrus::Contract::Account.create!(name: 'test') }
    it 'should create a record in database' do
      account = subject
      expect(Tapyrus::Contract::AR::Account.count).to eq 1
      expect(account.name).to eq 'test'
      expect(account.path).to eq "m/44'/0'/1'"
    end
  end

  describe 'self.load' do
    let!(:account) { Tapyrus::Contract::Account.create!(name: 'test') }
    it 'should load collect attributes' do
      loaded = Tapyrus::Contract::Account.load(account.index)
      expect(loaded.index).to eq account.index
      expect(loaded.name).to eq 'test'
    end

    it 'should load collect attributes' do
      expect { Tapyrus::Contract::Account.load(account.index + 1) }
        .to raise_error("Can not load the account. account_index = #{account.index + 1}")
    end
  end

  describe 'create_receive' do
    let!(:account) { Tapyrus::Contract::Account.create!(name: 'test') }
    it 'create collect keys and Address record to the database' do
      key1 = account.create_receive
      expect(Tapyrus::Contract::AR::Address.count).to eq 1
      expect(key1).to eq master_key.derive("m/44'/0'/1'/0/0")

      address = Tapyrus::Contract::AR::Address.first
      expect(address.account).to eq account.ar
      expect(address.change).to be_falsey
      expect(address.address_index).to eq 0
      expect(address.pubkey).to eq master_key.derive("m/44'/0'/1'/0/0").pub

      key2 = account.create_receive
      expect(Tapyrus::Contract::AR::Address.count).to eq 2
      expect(key2).to eq master_key.derive("m/44'/0'/1'/0/1")

      key3 = account.create_receive
      expect(Tapyrus::Contract::AR::Address.count).to eq 3
      expect(key3).to eq master_key.derive("m/44'/0'/1'/0/2")
    end
  end

  describe 'create_change' do
    let!(:account) { Tapyrus::Contract::Account.create!(name: 'test') }
    it 'create collect keys and Address record to the database' do
      key1 = account.create_change
      expect(Tapyrus::Contract::AR::Address.count).to eq 1
      expect(key1).to eq master_key.derive("m/44'/0'/1'/1/0")

      address = Tapyrus::Contract::AR::Address.first
      expect(address.account).to eq account.ar
      expect(address.change).to be_truthy
      expect(address.address_index).to eq 0
      expect(address.pubkey).to eq master_key.derive("m/44'/0'/1'/1/0").pub

      key2 = account.create_change
      expect(Tapyrus::Contract::AR::Address.count).to eq 2
      expect(key2).to eq master_key.derive("m/44'/0'/1'/1/1")

      key3 = account.create_change
      expect(Tapyrus::Contract::AR::Address.count).to eq 3
      expect(key3).to eq master_key.derive("m/44'/0'/1'/1/2")
    end
  end

  describe 'get derived keys' do
    let!(:account) { Tapyrus::Contract::Account.create!(name: 'test') }
    let!(:receive_keys) { 5.times.map { account.create_receive } }
    let!(:change_keys) { 5.times.map { account.create_change } }

    it 'gets all derived keys' do
      expect(account.derived_receive_keys).to eq receive_keys.map { |i| i.ext_pubkey }
      expect(account.derived_change_keys).to eq change_keys.map { |i| i.ext_pubkey }
    end
  end
end