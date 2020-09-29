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
    allow(rpc).to receive(:getblock).with('022890167018b090211fb8ef26970c26a0cac6d29e5352f506dc31bbb84f3ce7', 0).and_return(response_getblock)
    allow(rpc).to receive(:getrawtransaction).with('2acb0d1015c382d63d4d8404b3219fc37c2c5c49aa6d6994f654758fb0179071').and_return(response_getrawtransaction1)
    allow(rpc).to receive(:getrawtransaction).with('b4d0dbafa6777d8a902cf4359bdf1bdca3dbaca9ad450f284530cf039f49a23b').and_return(response_getrawtransaction2)
    setup_database

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
  let(:private_key) { 'ab2e2ba4c0605a3bd4f7734807e3346bae01290ebbaa0289c5c36912f7343650' }
  let(:rpc) { double('mock') }

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

  describe '#import_block' do
    subject { @rake['glueby:contract:wallet_adapter:import_block'].invoke('022890167018b090211fb8ef26970c26a0cac6d29e5352f506dc31bbb84f3ce7') }

    after { @rake['glueby:contract:wallet_adapter:import_block'].reenable }

    it do
      expect(rpc).to receive(:getblock).once
      expect(rpc).to receive(:getrawtransaction).twice
      subject
      expect(Glueby::Internal::Wallet::AR::Utxo::find_by(txid: 'd176b97d76488de0a85609c359eba1ceb357e739c334aa93ed16eff1fd86c06e', index: 0)).to be_nil
      expect(Glueby::Internal::Wallet::AR::Utxo::find_by(txid: 'b4d0dbafa6777d8a902cf4359bdf1bdca3dbaca9ad450f284530cf039f49a23b', index: 0)).not_to be_nil
    end
    it { expect { subject }.to change { Glueby::Internal::Wallet::AR::Utxo.count }.from(1).to(2) }
  end

  describe '#import_tx' do
    subject { @rake['glueby:contract:wallet_adapter:import_tx'].invoke('b4d0dbafa6777d8a902cf4359bdf1bdca3dbaca9ad450f284530cf039f49a23b') }

    after { @rake['glueby:contract:wallet_adapter:import_tx'].reenable }

    it do
      expect(rpc).to receive(:getrawtransaction).once
      subject
      expect(Glueby::Internal::Wallet::AR::Utxo::find_by(txid: 'd176b97d76488de0a85609c359eba1ceb357e739c334aa93ed16eff1fd86c06e', index: 0)).to be_nil
      expect(Glueby::Internal::Wallet::AR::Utxo::find_by(txid: 'b4d0dbafa6777d8a902cf4359bdf1bdca3dbaca9ad450f284530cf039f49a23b', index: 0)).not_to be_nil
    end
    it { expect { subject }.not_to change { Glueby::Internal::Wallet::AR::Utxo.count } }

    context 'if tx is not associated with glueby wallet' do
      let(:private_key) { '22f774bbcf6a39b3dbeb47761b4d83b5cb0c6cf558db7c400ddd2bbe19cc3e79' }

      it { expect { subject }.to change { Glueby::Internal::Wallet::AR::Utxo.count }.from(1).to(0) }
    end
  end
end
