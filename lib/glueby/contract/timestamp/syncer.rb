module Glueby
  module Contract
    class Timestamp
      class Syncer
        def block_sync(block)
          Glueby::Contract::AR::Timestamp
            .where(txid: block.transactions.map(&:txid), status: :unconfirmed)
            .update_all(status: :confirmed)
        end
      end
    end
  end
end
