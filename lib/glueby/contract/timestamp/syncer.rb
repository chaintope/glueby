module Glueby
  module Contract
    class Timestamp
      class Syncer
        def block_sync(block)
          Glueby::Contract::AR::Timestamp
            .where(txid: block.transactions.map(&:txid), status: :unconfirmed)
            .update_all(status: :confirmed)
        end

        def self.enabled?
          Glueby::Contract::AR::Timestamp.table_exists?
        end
      end
    end
  end
end
