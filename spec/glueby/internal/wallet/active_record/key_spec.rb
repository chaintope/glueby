# frozen_string_literal: true

require 'active_record'

RSpec.describe 'Glueby::Internal::Wallet::AR::Key' do
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

  let(:key) { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key, purpose: :change) }
  let(:private_key) { '206f3acb5b7ac66dacf87910bb0b04bed78284b9b50c0d061705a44447a947ff' }
  let(:config) { { adapter: 'sqlite3', database: 'test' } }

  before { setup_database }
  after do
    connection = ::ActiveRecord::Base.connection
    connection.drop_table :utxos, if_exists: true
    connection.drop_table :keys, if_exists: true
  end

  describe '#valid' do
    subject { key }

    context 'no purpose' do
      let(:key) { Glueby::Internal::Wallet::AR::Key.new(private_key: private_key) }

      it { is_expected.to be_invalid }
    end

    context 'purpose is receive' do
      let(:key) { Glueby::Internal::Wallet::AR::Key.new(private_key: private_key, purpose: :receive) }

      it { is_expected.to be_valid }
    end

    context 'purpose is change' do
      let(:key) { Glueby::Internal::Wallet::AR::Key.new(private_key: private_key, purpose: :change) }

      it { is_expected.to be_valid }
    end

    context 'purpose is other' do
      let(:key) { Glueby::Internal::Wallet::AR::Key.new(private_key: private_key, purpose: :other) }

      it { expect{ subject }.to raise_error ArgumentError, "'other' is not a valid purpose" }
    end

    context 'private_key is not unique' do
      before { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key, purpose: :receive) }

      it { is_expected.to be_invalid }
    end

    context 'private_key is lower case' do
      before { Glueby::Internal::Wallet::AR::Key.create(private_key: '206F3ACB5B7AC66DACF87910BB0B04BED78284B9B50C0D061705A44447A947FF', purpose: :receive) }

      it { is_expected.to be_invalid }
    end
  end

  describe '#generate_key' do
    subject { key }

    let(:private_key) { nil }

    it { expect(subject.public_key).not_to be_nil }
    it { expect(subject.private_key).not_to be_nil }
  end

  describe '#to_p2pkh' do
    subject { key.to_p2pkh.to_hex }

    it { expect(subject).to eq '76a91457dd450aed53d4e35d3555a24ae7dbf3e08a78ec88ac' }
  end

  describe '#sign' do
    subject { key.sign(data).bth }

    let(:data) { '61b04781dec482815d8fc22d6074a57e184973e96870e2f59dab0a5851b1b4dd'.htb }

    it { expect(subject).to eq '20661fb45b90f336c150ef7ee1dbcf6872e6e1af34a5d71878d4590e42722500d5ba107944d679a3b9ac30de6f2cbc586498e5a09fdfdeb9c3a3af9971212cda' }
    it { expect(Tapyrus::Key.new(priv_key: private_key).verify(subject.htb, data, algo: :schnorr)).to be_truthy }
  end

  describe '.key_for_output' do
    subject { Glueby::Internal::Wallet::AR::Key.key_for_output(output) }

    let(:output) { Tapyrus::TxOut.new(value: 1, script_pubkey: script) }
    let(:script) { Tapyrus::Script.parse_from_payload(key.script_pubkey.htb) }

    context 'key exists' do
      it { is_expected.to eq key }
    end

    context 'key does not exist' do
      let(:script) { Tapyrus::Script.new }

      it { is_expected.to be_nil }
    end

    context 'output is colored' do
      let(:script) { Tapyrus::Script.parse_from_payload(key.script_pubkey.htb).add_color(color_id) }
      let(:color_id) { Tapyrus::Color::ColorIdentifier.parse_from_payload('c185856a84c483fb108b1cdf79ff53aa7d54d1a137a5178684bd89ca31f906b2bd'.htb) }

      it { is_expected.to eq key }
    end
  end

  describe '.key_for_script' do
    subject { Glueby::Internal::Wallet::AR::Key.key_for_script(script) }

    let(:script) { Tapyrus::Script.parse_from_payload(key.script_pubkey.htb) }

    context 'key exists' do
      it { is_expected.to eq key }
    end

    context 'key does not exist' do
      let(:script) { Tapyrus::Script.new }
      it { is_expected.to be_nil }
    end

    context 'script is colored' do
      let(:script) { Tapyrus::Script.parse_from_payload(key.script_pubkey.htb).add_color(color_id) }
      let(:color_id) { Tapyrus::Color::ColorIdentifier.parse_from_payload('c185856a84c483fb108b1cdf79ff53aa7d54d1a137a5178684bd89ca31f906b2bd'.htb) }

      it { is_expected.to eq key }
    end
  end
end
