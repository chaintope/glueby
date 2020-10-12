# frozen_string_literal: true

require 'active_record'

RSpec.describe 'Glueby::Internal::Wallet::AR::Wallet' do
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

  let(:wallet) { Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF') }
  let(:config) { { adapter: 'sqlite3', database: 'test' } }

  before { setup_database }
  after do
    connection = ::ActiveRecord::Base.connection
    connection.drop_table :utxos, if_exists: true
    connection.drop_table :wallets, if_exists: true
    connection.drop_table :keys, if_exists: true
  end

  describe '#sign' do
    subject { wallet.sign(tx) }

    let(:key1) { wallet.keys.create(purpose: :receive) }
    let(:key2) { wallet.keys.create(purpose: :receive) }
    let(:tx) do
      tx = Tapyrus::Tx.new
      tx.inputs << Tapyrus::TxIn.new(out_point: Tapyrus::OutPoint.new('00' * 32, 0))
      tx.inputs << Tapyrus::TxIn.new(out_point: Tapyrus::OutPoint.new('11' * 32, 0))
      tx.inputs << Tapyrus::TxIn.new(out_point: Tapyrus::OutPoint.new('22' * 32, 0))
      tx.outputs << Tapyrus::TxOut.new(value: 1, script_pubkey: Tapyrus::Script.new)
      tx
    end
    let(:color_id) { Tapyrus::Color::ColorIdentifier.parse_from_payload('c185856a84c483fb108b1cdf79ff53aa7d54d1a137a5178684bd89ca31f906b2bd'.htb) }

    before do
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '0000000000000000000000000000000000000000000000000000000000000000',
        index: 0,
        value: 1,
        script_pubkey: key1.to_p2pkh.to_hex,
        status: :init,
        key: key1
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '1111111111111111111111111111111111111111111111111111111111111111',
        index: 0,
        value: 1,
        script_pubkey: key2.to_p2pkh.to_hex,
        status: :init,
        key: key2
      )
      colored_script = key1.to_p2pkh.add_color(color_id)
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: '2222222222222222222222222222222222222222222222222222222222222222',
        index: 0,
        script_pubkey: colored_script.to_hex,
        value: 1,
        status: :finalized,
        key: key1
      )
    end

    it do
      subject
      expect(tx.verify_input_sig(0, key1.to_p2pkh)).to be_truthy
      expect(tx.verify_input_sig(1, key2.to_p2pkh)).to be_truthy
      expect(tx.verify_input_sig(2, key1.to_p2pkh.add_color(color_id))).to be_truthy
    end
  end

  describe '#valid' do
    subject { wallet }
    
    context 'wallet_id is unique' do
      it { is_expected.to be_valid }
    end

    context 'wallet_id is not unique' do
      before { Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF') }

      it { is_expected.to be_invalid }
    end

    context 'wallet_id is lower case' do
      before { Glueby::Internal::Wallet::AR::Wallet.create(wallet_id: 'ffffffffffffffffffffffffffffffff') }

      it { is_expected.to be_invalid }
    end
  end
end
