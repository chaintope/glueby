namespace :glueby do
  namespace :utxo_provider do
    desc 'Manage the UTXO pool in Glueby::UtxoProvider. Creates outputs for paying utxo if the outputs is less than configured pool size by :utxo_pool_size'
    task :manage_utxo_pool, [] => [:environment] do |_, _|
      Glueby::UtxoProvider::Tasks.new.manage_utxo_pool
    end

    desc 'Show the status of the UTXO pool in Glueby::UtxoProvider'
    task :status, [] => [:environment] do |_, _|
      Glueby::UtxoProvider::Tasks.new.status
    end

    desc 'Show the address of the Glueby::UtxoProvider'
    task :address, [] => [:environment] do |_, _|
      Glueby::UtxoProvider::Tasks.new.print_address
    end
  end
end
