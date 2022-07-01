module Glueby
  module Contract
    class TokenGenerator < Rails::Generators::Base
      include ::Rails::Generators::Migration
      include Glueby::Generator::MigrateGenerator
      extend Glueby::Generator::MigrateGenerator::ClassMethod

      source_root File.expand_path('templates', __dir__)

      def create_migration_file
        migration_dir = File.expand_path("db/migrate")

        if self.class.migration_exists?(migration_dir, "create_token_metadata")
          ::Kernel.warn "Migration already exists: create_token_metadata"
        else
          migration_template(
            "token_metadata_table.rb.erb",
            "db/migrate/create_token_metadata.rb",
            migration_version: migration_version,
            table_options: table_options,
          )
        end
      end
    end
  end
end
