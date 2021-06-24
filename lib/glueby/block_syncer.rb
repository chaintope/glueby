module Glueby
  # You can use BlockSyncer when you need to synchronize the state of
  # an application with the state of a blockchain. When BlockSyncer
  # detects the generation of a new block, it executes the registered
  # syncer code on a block-by-block or transaction-by-transaction basis.
  # By using this, an application can detect that the issued transaction
  # has been captured in  blocks, receive a new remittance, and so on.
  #
  # # Syncer logic registration
  #
  # For registration, create a class that implements the method that performs
  # synchronization processing and registers it in BlockSyncer. Implement
  # methods with the following name in that class.
  #
  # Method name        | Arguments             | Call conditions
  # ------------------ | --------------------- | ------------------------------
  # block_sync (block) | block: Tapyrus::Block | When a new block is created
  # block_tx (tx)      | tx: Tapyrus::Tx       | When a new block is created, it is executed for each tx contained in that block.
  #
  # @example Register a synchronous logic
  #   class Syncer
  #     def block_sync (block)
  #       # sync a block
  #     end
  #
  #     def tx_sync (tx)
  #       # sync a tx
  #     end
  #   end
  #   BlockSyncer.register_syncer(Syncer)
  #
  # @example Unregister the synchronous logic
  #   BlockSyncer.unregister_syncer(Syncer)
  #
  # # Run BlockSyncer
  #
  # Run the `glueby: block_syncer: start` rake task periodically with a program
  # for periodic execution such as cron. If it detects the generation of a new
  # block when it is executed, the synchronization process will be executed.
  # Determine the execution interval according to the requirements of the application.
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