module Tapyrus
  module Contract
    module Task
      module Timestamp
        module_function
        extend Tapyrus::Contract::TxBuilder
        extend Tapyrus::Contract::Timestamp::Util

        def create
          timestamps = Tapyrus::Contract::AR::Timestamp.where(status: :init)
          timestamps.each do |t|
            begin
              ::ActiveRecord::Base.transaction do
                tx = create_tx(t.prefix, t.content_hash, Tapyrus::Contract::FixedFeeProvider.new)
                signed_tx = sign_tx(tx)
                t.update(txid: signed_tx.txid, status: :unconfirmed)

                broadcast_tx(signed_tx)
                puts "broadcasted (id=#{t.id}, txid=#{signed_tx.txid})"
              end
            rescue => e
              puts "failed to broadcast (id=#{t.id}, reason=#{e.message})"
            end
          end
        end

        def confirm
          timestamps = Tapyrus::Contract::AR::Timestamp.where(status: :unconfirmed)
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

namespace :tapyrus do
  namespace :contract do
    namespace :timestamp do
      desc 'create and broadcast tapyrus timestamp tx'
      task :create, [] => [:environment] do |_, _|
        Tapyrus::Contract::Task::Timestamp.create
      end

      desc 'confirm tapyrus timestamp tx'
      task :confirm, [] => [:environment] do |_, _|
        Tapyrus::Contract::Task::Timestamp.confirm
      end
    end
  end
end