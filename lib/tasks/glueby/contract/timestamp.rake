module Glueby
  module Contract
    module Task
      module Timestamp
        module_function
        extend Glueby::Contract::TxBuilder
        extend Glueby::Contract::Timestamp::Util

        def create
          timestamps = Glueby::Contract::AR::Timestamp.where(status: :init)
          timestamps.each do |t|
            begin
              ::ActiveRecord::Base.transaction do
                wallet = Glueby::Wallet.load(t.wallet_id)
                tx = create_tx(wallet, t.prefix, t.content_hash, Glueby::Contract::FixedFeeEstimator.new)
                t.update(txid: tx.txid, status: :unconfirmed)

                wallet.internal_wallet.broadcast(tx)
                puts "broadcasted (id=#{t.id}, txid=#{tx.txid})"
              end
            rescue => e
              puts "failed to broadcast (id=#{t.id}, reason=#{e.message})"
            end
          end
        end

        def confirm
          timestamps = Glueby::Contract::AR::Timestamp.where(status: :unconfirmed)
          timestamps.each do |t|
            begin
              ::ActiveRecord::Base.transaction do
                tx = get_transaction(t)
                if tx['confirmations'] &&  tx['confirmations'] > 0
                  t.update(status: :confirmed)
                  puts "confirmed (id=#{t.id}, txid=#{tx['txid']})"
                end
              end
            rescue => e
              puts "failed to confirm (id=#{t.id}, reason=#{e.message})"
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

      desc 'confirm glueby timestamp tx'
      task :confirm, [] => [:environment] do |_, _|
        Glueby::Contract::Task::Timestamp.confirm
      end
    end
  end
end