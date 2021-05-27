namespace :glueby do
  namespace :fee_provider do
    desc 'Manage the UTXO pool in Glueby::FeeProvider. Creates outputs for paying fee if the outputs is less than configured pool size by :utxo_pool_size'
    task :manage_utxo_pool, [] => [:environment] do |_, _|
      Glueby::FeeProvider::Tasks.new.manage_utxo_pool
    end

    desc 'Show the status of the UTXO pool in Glueby::FeeProvider'
    task :status, [] => [:environment] do |_, _|
      Glueby::FeeProvider::Tasks.new.status
    end
  end
end
