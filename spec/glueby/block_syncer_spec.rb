# frozen_string_literal: true

RSpec.describe Glueby::BlockSyncer do
  subject { described_class.new(height).run }

  class DummySyncer
    def tx_sync(_tx); end
    def block_sync(_block); end
  end

  class DummyTxSyncer
    def tx_sync(_tx); end

    def method_missing(symbol, *args)
      fail if symbol == :block_sync
    end
  end

  class DummyBlockSyncer
    def block_sync(_block); end

    def method_missing(symbol, *args)
      fail if symbol == :tx_sync
    end
  end

  let(:height) { 0 }
  let(:block) { Tapyrus::Block.parse_from_payload(response_getblock.htb) }

  setup_responses

  before do
    allow(Glueby::Internal::RPC).to receive(:client).and_return(rpc)
    allow(rpc).to receive(:getblockhash).with(0).and_return('022890167018b090211fb8ef26970c26a0cac6d29e5352f506dc31bbb84f3ce7')
    allow(rpc).to receive(:getblock).with('022890167018b090211fb8ef26970c26a0cac6d29e5352f506dc31bbb84f3ce7', 0).and_return(response_getblock)

    Glueby::BlockSyncer.register_syncer(DummySyncer)
    Glueby::BlockSyncer.register_syncer(DummyTxSyncer)
    Glueby::BlockSyncer.register_syncer(DummyBlockSyncer)
  end

  after do
    Glueby::BlockSyncer.unregister_syncer(DummySyncer)
    Glueby::BlockSyncer.unregister_syncer(DummyTxSyncer)
    Glueby::BlockSyncer.unregister_syncer(DummyBlockSyncer)
  end

  it 'calls registered sync methods' do
    expect_any_instance_of(DummySyncer).to receive(:tx_sync).twice
    expect_any_instance_of(DummySyncer).to receive(:block_sync).once
    expect_any_instance_of(DummyTxSyncer).to receive(:tx_sync).twice
    expect_any_instance_of(DummyBlockSyncer).to receive(:block_sync).once
    subject
  end

  context 'unregister a syncer' do
    before do
      Glueby::BlockSyncer.unregister_syncer(DummySyncer)
    end

    it 'calls registered sync methods' do
      expect_any_instance_of(DummyTxSyncer).to receive(:tx_sync).twice
      expect_any_instance_of(DummyBlockSyncer).to receive(:block_sync).once
      subject
    end
  end
end