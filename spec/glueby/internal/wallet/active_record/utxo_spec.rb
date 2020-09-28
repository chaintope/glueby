# frozen_string_literal: true

require 'active_record'

RSpec.describe 'Glueby::Internal::Wallet::AR::Utxo' do
  def setup_database
    ::ActiveRecord::Base.establish_connection(config)
    connection = ::ActiveRecord::Base.connection
    connection.create_table :utxos do |t|
      t.string     :txid
      t.integer    :index
      t.bigint     :value
      t.string     :script_pubkey
      t.boolean    :spent
      t.integer    :status
      t.belongs_to :key, null: true
      t.timestamps
    end
    connection.add_index :utxos, [:txid, :index], unique: true
  end

  let(:utxo) do
    Glueby::Internal::Wallet::AR::Utxo.create(
      txid: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
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
          txid: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
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
          txid: 'fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
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
          txid: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF',
          index: 1,
          script_pubkey: '21c3ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
          value: 1,
          status: :init
        )
        Glueby::Internal::Wallet::AR::Utxo.create(
          txid: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE',
          index: 0,
          script_pubkey: '21c3ec2fd806701a3f55808cbec3922c38dafaa3070c48c803e9043ee3642c660b46bc76a91446c2fbfbecc99a63148fa076de58cf29b0bcf0b088ac',
          value: 1,
          status: :init
        )
      end

      it { is_expected.to be_valid }
    end
  end
end
