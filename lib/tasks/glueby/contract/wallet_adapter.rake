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
          tx.inputs.each do |input|
            Glueby::Internal::Wallet::AR::Utxo.destroy_by(txid: input.out_point.txid, index: input.out_point.index)
          end

          tx.outputs.each.with_index do |output, index|
            script_pubkey = if output.colored?
              output.script_pubkey.remove_color.to_hex
            else
              output.script_pubkey.to_hex
            end
            key = Glueby::Internal::Wallet::AR::Key.find_by(script_pubkey: script_pubkey)
            next unless key

            Glueby::Internal::Wallet::AR::Utxo.create(
              txid: txid,
              index: index,
              script_pubkey: output.script_pubkey.to_hex,
              value: output.value,
              status: :finalized,
              key: key
            )
          end
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

        import_block(block_hash)
      end

      desc 'import transaction into database'
      task :import_tx, [:txid] => [:environment] do |_, args|
        txid = args[:txid]

        import_tx(txid)
      end
    end
  end
end