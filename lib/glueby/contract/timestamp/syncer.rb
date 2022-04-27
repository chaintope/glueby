module Glueby
  module Contract
    class Timestamp
      class Syncer
        def block_sync(block)
          Glueby::Contract::AR::Timestamp
            .where(txid: block.transactions.map(&:txid), status: :unconfirmed)
            .update_all(status: :confirmed, block_height: block.height, block_time: block.header.time)
        end
      end
    end
  end
end
