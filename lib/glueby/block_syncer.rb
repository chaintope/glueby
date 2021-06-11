module Glueby
  # Synchronize a block from blockchain to Glueby modules.
  # Any synchronous logics can be registered and it is called when new blocks received.
  #
  # @example Register a synchronous logic
  #   class Syncer
  #     def block_sync(block)
  #       # synchronize the block
  #     end
  #
  #     def tx_sync(tx)
  #       # synchronize the tx
  #     end
  #   end
  #
  #   BlockSyncer.register_syncer(Syncer)
  #
  # @example Unregister the synchronous logic
  #   BlockSyncer.unregister_syncer(Syncer)
  #
  class BlockSyncer
    # @!attribute [r] height
    #   @return [Integer] The block height to be synced
    attr_reader :height

    class << self
      # @!attribute r syncers
      #   @return [Array<Class>] The syncer classes that is registered
      attr_reader :syncers

      # Register syncer class
      # @param [Class] syncer The syncer to be registered.
      def register_syncer(syncer)
        @syncers ||= []
        @syncers << syncer
      end

      # Unregister syncer class
      # @param [Class] syncer The syncer to be unregistered.
      def unregister_syncer(syncer)
        @syncers ||= []
        @syncers.delete(syncer)
      end
    end

    # @param [Integer] height The block height to be synced in the instance
    def initialize(height)
      @height = height
    end

    # Run a block synchronization
    def run
      return if self.class.syncers.nil?

      self.class.syncers.each do |syncer|
        instance = syncer.new
        instance.block_sync(block) if instance.respond_to?(:block_sync)

        if instance.respond_to?(:tx_sync)
          block.transactions.each { |tx| instance.tx_sync(tx) }
        end
      end
    end

    private

    def block
      @block ||= begin
                   block = Glueby::Internal::RPC.client.getblock(block_hash, 0)
                   Tapyrus::Block.parse_from_payload(block.htb)
                 end
    end

    def block_hash
      @block_hash ||= Glueby::Internal::RPC.client.getblockhash(height)
    end
  end
end