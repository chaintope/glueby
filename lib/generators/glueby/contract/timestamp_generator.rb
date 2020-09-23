module Glueby
  module Contract
    class TimestampGenerator < Rails::Generators::Base
      include ::Rails::Generators::Migration
      include Glueby::Generator::MigrateGenerator
      extend Glueby::Generator::MigrateGenerator::ClassMethod

      source_root File.expand_path('templates', __dir__)

      def create_migration_file
        migration_dir = File.expand_path("db/migrate")

        if self.class.migration_exists?(migration_dir, "create_timestamp")
          ::Kernel.warn "Migration already exists: create_timestamp"
        else
          migration_template(
            "timestamp_table.rb.erb",
            "db/migrate/create_timestamp.rb",
            migration_version: migration_version,
            table_options: table_options,
          )
        end
      end
    end
  end
end
