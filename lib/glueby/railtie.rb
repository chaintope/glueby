module Glueby
  class Railtie < ::Rails::Railtie
    initializer "glueby.register_syncers" do
      BlockSyncer.register_syncer(Contract::Timestamp::Syncer)
    end

    rake_tasks do
      load "tasks/glueby/contract.rake"
      load "tasks/glueby/contract/timestamp.rake"
      load "tasks/glueby/block_syncer.rake"
      load "tasks/glueby/fee_provider.rake"
    end
  end
end