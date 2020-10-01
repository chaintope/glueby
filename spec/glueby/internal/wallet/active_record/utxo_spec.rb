# frozen_string_literal: true

require 'active_record'

RSpec.describe 'Glueby::Internal::Wallet::AR::Utxo' do
  def setup_database
    ::ActiveRecord::Base.establish_connection(config)
    connection = ::ActiveRecord::Base.connection

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

  let(:utxo) do
    Glueby::Internal::Wallet::AR::Utxo.create(
      txid: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
      index: 0,
      script_pubkey: '21c3ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
      value: 1,
      status: :init
    )
  end
  let(:config) { { adapter: 'sqlite3', database: 'test' } }

  before { setup_database }
  after do
    connection = ::ActiveRecord::Base.connection
    connection.drop_table :utxos, if_exists: true
    connection.drop_table :keys, if_exists: true
  end

  describe '#color_id' do
    subject { utxo.color_id }

    it { is_expected.to eq 'c3ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46' }
  end

  describe '#valid' do
    subject { utxo }

    context '[txid, index] is not unique' do
      before do
        Glueby::Internal::Wallet::AR::Utxo.create(
          txid: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
          index: 0,
          script_pubkey: '21c3ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
          value: 1,
          status: :init
        )
      end

      it { is_expected.to be_invalid }
    end

    context 'txid is lower case' do
      before do
        Glueby::Internal::Wallet::AR::Utxo.create(
          txid: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          index: 0,
          script_pubkey: '21c3ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
          value: 1,
          status: :init
        )
      end

      it { is_expected.to be_invalid }
    end

    context '[txid, index] is unique' do
      before do
        Glueby::Internal::Wallet::AR::Utxo.create(
          txid: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
          index: 1,
          script_pubkey: '21c3ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
          value: 1,
          status: :init
        )
        Glueby::Internal::Wallet::AR::Utxo.create(
          txid: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE',
          index: 0,
          script_pubkey: '21c3ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
          value: 1,
          status: :init
        )
      end

      it { is_expected.to be_valid }
    end
  end

  describe '.destroy_for_inputs' do
    subject { Glueby::Internal::Wallet::AR::Utxo.destroy_for_inputs(tx) }

    let(:tx) do
      Tapyrus::Tx.new.tap do |tx|
        tx.inputs << Tapyrus::TxIn.new(out_point: Tapyrus::OutPoint.from_txid('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF', 0))
        tx.inputs << Tapyrus::TxIn.new(out_point: Tapyrus::OutPoint.from_txid('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF', 1))
      end
    end

    before do
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        index: 0,
        script_pubkey: '21c3ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
        value: 1,
        status: :init
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        index: 1,
        script_pubkey: '21c3ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
        value: 1,
        status: :init
      )
      Glueby::Internal::Wallet::AR::Utxo.create(
        txid: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        index: 2,
        script_pubkey: '21c3ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
        value: 1,
        status: :init
      )
    end

    it { expect { subject }.to change { Glueby::Internal::Wallet::AR::Utxo.count }.from(3).to(1) }
  end

  describe '.create_for_outputs' do
    subject { Glueby::Internal::Wallet::AR::Utxo.create_for_outputs(tx) }

    let(:tx) do
      Tapyrus::Tx.new.tap do |tx|
        tx.outputs << Tapyrus::TxOut.new(value: 1, script_pubkey: Tapyrus::Script.parse_from_payload('76a91457dd450aed53d4e35d3555a24ae7dbf3e08a78ec88ac'.htb))
        tx.outputs << Tapyrus::TxOut.new(value: 1, script_pubkey: Tapyrus::Script.parse_from_payload('21c3ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91457dd450aed53d4e35d3555a24ae7dbf3e08a78ec88ac'.htb))
      end
    end
    let(:private_key) { '206f3acb5b7ac66dacf87910bb0b04bed78284b9b50c0d061705a44447a947ff' }

    before { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key, purpose: :change) }

    it { expect { subject }.to change { Glueby::Internal::Wallet::AR::Utxo.count }.from(0).to(2) }
  end
end
