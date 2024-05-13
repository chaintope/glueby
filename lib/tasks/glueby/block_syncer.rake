require 'tasks/glueby/task_helper'

extend TaskHelper

namespace :glueby do
  namespace :contract do
    namespace :block_syncer do
      desc '[Deprecated use glueby:block_syncer:start instead] sync block into database'
      task :start, [] => [:environment] do |_, _|
        logger.info('[Deprecated] glueby:contract:block_syncer:start is deprecated. Use \'glueby:block_syncer:start\'')
        Rake::Task['glueby:block_syncer:start'].execute
      end
    end
  end
end


namespace :glueby do
  namespace :block_syncer do
    desc 'sync block into database'
    task :start, [] => [:environment] do |_, _|
      latest_block_num = Glueby::Internal::RPC.client.getblockcount
      synced_block = Glueby::AR::SystemInformation.synced_block_height
      (synced_block.int_value + 1..latest_block_num).each do |height|
        ::ActiveRecord::Base.transaction do
          Glueby::BlockSyncer.new(height).run
          synced_block.update(info_value: height.to_s)
        end
        logger.info("success in synchronization (block height=#{height})")
      end
    end

    desc 'Update the block height in Glueby::AR::SystemInformation and do not run Glueby::BlockSyncer. This task is intended to skip the synchronization process until the latest block height.'
    task :update_height, [] => [:environment] do |_, _|
      new_height = Glueby::Internal::RPC.client.getblockcount
      synced_block = Glueby::AR::SystemInformation.synced_block_height
      synced_block.update(info_value: new_height.to_s)
    end
  end
end