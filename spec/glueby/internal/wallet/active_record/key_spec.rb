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
  end

  let(:key) { Glueby::Internal::Wallet::AR::Key.create(private_key: private_key, purpose: :change) }
  let(:private_key) { '206f3acb5b7ac66dacf87910bb0b04bed78284b9b50c0d061705a44447a947ff' }
  let(:config) { { adapter: 'sqlite3', database: 'test' } }

  before { setup_database }
  after do
    connection = ::ActiveRecord::Base.connection
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

    it { expect(subject).to eq '304402201322a9efb6b21cbacfc814db423c72347e616d39bcf2fd36934a3e584c40e9330220085a7c1076bfcdf58917694a5d8f453f480abb4c32e0840ea60576b1718519f5' }
  end
end
