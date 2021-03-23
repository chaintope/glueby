module Glueby
  module Contract
    module Task
      module BlockSyncer

        def sync_block
          latest_block_num = Glueby::Internal::RPC.client.getblockcount
          synced_block_info = Glueby::AR::SystemInformation.find_by(info_key: "synced_block_number")
          saved_block = Glueby::AR::SystemInformation.synced_block_height
          (saved_block..latest_block_num).each do |i|
            ::ActiveRecord::Base.transaction do
              block_hash = Glueby::Internal::RPC.client.getblockhash(i)
              import_block(block_hash)
              synced_block_info.update(info_value: i.to_s)
              puts "success in synchronization (block height=#{i.to_s})"
            end
          end
        end 

      end
    end
  end
end

namespace :glueby do
  namespace :contract do
    namespace :block_syncer do
      include Glueby::Contract::Task::BlockSyncer

      desc 'sync block into database'
      task :start, [] => [:environment] do |_, _|
        Glueby::Contract::Task::BlockSyncer.sync_block
      end

    end
  end
end