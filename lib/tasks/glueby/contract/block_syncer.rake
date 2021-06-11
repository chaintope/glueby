namespace :glueby do
  namespace :contract do
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
          puts "success in synchronization (block height=#{height})"
        end
      end
    end
  end
end