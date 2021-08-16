# frozen_string_literal: true

RSpec.describe 'Glueby::Railtie', active_record: true do
  require 'rails'
  require 'glueby/railtie'
  subject { Glueby::Railtie.initializers.each(&:run) }

  it do
    expect(Glueby::BlockSyncer).to receive(:register_syncer).with(Glueby::Contract::Timestamp::Syncer)
    subject
  end

  context 'if glueby_timestamp table not created' do
    before { ::ActiveRecord::Base.connection.drop_table :glueby_timestamps, if_exists: true }

    it do
      expect(Glueby::BlockSyncer).not_to receive(:register_syncer)
      subject
    end
  end
end
