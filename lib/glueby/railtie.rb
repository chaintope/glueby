module Glueby
  class Railtie < ::Rails::Railtie
    rake_tasks do
      load "tasks/glueby/contract.rake"
      load "tasks/glueby/contract/timestamp.rake"
      load "tasks/glueby/block_syncer.rake"
      load "tasks/glueby/fee_provider.rake"
      load "tasks/glueby/utxo_provider.rake"
    end
  end
end