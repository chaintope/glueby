module Glueby
  class BlockSyncer

    attr_reader :height

    def initialize(height)
      @height = height
    end

    def run
      import_block(block_hash)
    end

    def block_hash
      @block_hash ||= Glueby::Internal::RPC.client.getblockhash(height)
    end
  end
end