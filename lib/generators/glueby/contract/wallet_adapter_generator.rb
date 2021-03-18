module Glueby
  module Contract
    class WalletAdapterGenerator < Rails::Generators::Base
      include ::Rails::Generators::Migration
      include Glueby::Generator::MigrateGenerator
      extend Glueby::Generator::MigrateGenerator::ClassMethod

      source_root File.expand_path('templates', __dir__)

      def create_migration_file
        migration_dir = File.expand_path("db/migrate")

        if self.class.migration_exists?(migration_dir, "create_wallet")
          ::Kernel.warn "Migration already exists: create_wallet"
        else
          migration_template(
            "wallet_table.rb.erb",
            "db/migrate/create_wallet.rb",
            migration_version: migration_version,
            table_options: table_options,
          )
        end
        if self.class.migration_exists?(migration_dir, "create_key")
          ::Kernel.warn "Migration already exists: create_key"
        else
          migration_template(
            "key_table.rb.erb",
            "db/migrate/create_key.rb",
            migration_version: migration_version,
            table_options: table_options,
          )
        end
        if self.class.migration_exists?(migration_dir, "create_utxo")
          ::Kernel.warn "Migration already exists: create_utxo"
        else
          migration_template(
            "utxo_table.rb.erb",
            "db/migrate/create_utxo.rb",
            migration_version: migration_version,
            table_options: table_options,
          )
        end
        if self.class.migration_exists?(migration_dir, "create_block")
          ::Kernel.warn "Migration already exists: create_block"
        else
          migration_template(
            "block_table.rb.erb",
            "db/migrate/create_block.rb",
            migration_version: migration_version,
            table_options: table_options,
          )
        end
      end
    end
  end
end
