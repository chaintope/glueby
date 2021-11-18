module Glueby
  module Contract
    module Task
      module Timestamp
        module_function
        extend Glueby::Contract::TxBuilder
        extend Glueby::Contract::Timestamp::Util

        def create
          timestamps = Glueby::Contract::AR::Timestamp.where(status: :init)
          utxo_provider = Glueby::UtxoProvider.new if Glueby.configuration.use_utxo_provider?
          timestamps.each do |t|
            begin
              wallet = Glueby::Wallet.load(t.wallet_id)
              funding_tx, tx = create_txs(wallet, t.prefix, t.content_hash, Glueby::Contract::FixedFeeEstimator.new, utxo_provider)
              if funding_tx
                ::ActiveRecord::Base.transaction do
                  wallet.internal_wallet.broadcast(funding_tx)
                  puts "funding tx was broadcasted(id=#{t.id}, funding_tx.txid=#{funding_tx.txid})"
                end
              end
              ::ActiveRecord::Base.transaction do
                wallet.internal_wallet.broadcast(tx) do |tx|
                  t.update(txid: tx.txid, status: :unconfirmed)
                end
                puts "timestamp tx was broadcasted (id=#{t.id}, txid=#{tx.txid})"
              end
            rescue => e
              puts "failed to broadcast (id=#{t.id}, reason=#{e.message})"
            end
          end
        end
      end
    end
  end
end

namespace :glueby do
  namespace :contract do
    namespace :timestamp do
      desc 'create and broadcast glueby timestamp tx'
      task :create, [] => [:environment] do |_, _|
        Glueby::Contract::Task::Timestamp.create
      end
    end
  end
end