module Glueby
  module Contract
    module Task
      module WalletAdapter
        def import_block(block_hash)
          block = Glueby::Internal::RPC.client.getblock(block_hash, 0)
          block = Tapyrus::Block.parse_from_payload(block.htb)
          block.transactions.each { |tx| import_tx(tx.txid) }
        end

        def import_tx(txid)
          tx = Glueby::Internal::RPC.client.getrawtransaction(txid)
          tx = Tapyrus::Tx.parse_from_payload(tx.htb)
          Glueby::Internal::Wallet::AR::Utxo.destroy_for_inputs(tx)
          Glueby::Internal::Wallet::AR::Utxo.create_for_outputs(tx)
        end
      end
    end
  end
end

namespace :glueby do
  namespace :contract do
    namespace :wallet_adapter do
      include Glueby::Contract::Task::WalletAdapter

      desc 'import block into database'
      task :import_block, [:block_hash] => [:environment] do |_, args|
        block_hash = args[:block_hash]

        ::ActiveRecord::Base.transaction { import_block(block_hash) }
      end

      desc 'import transaction into database'
      task :import_tx, [:txid] => [:environment] do |_, args|
        txid = args[:txid]

        ::ActiveRecord::Base.transaction { import_tx(txid) }
      end
    end
  end
end