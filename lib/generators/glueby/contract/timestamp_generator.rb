module Glueby
  module Contract
    class TimestampGenerator < Rails::Generators::Base
      include ::Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      def self.next_migration_number(dirname)
        # ::ActiveRecord::Migration.next_migration_number(number)
        # ::ActiveRecord::Generators::Base.next_migration_number(dirname)
        next_migration_number = current_migration_number(dirname) + 1
        ::ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

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

      MYSQL_ADAPTERS = [
        "ActiveRecord::ConnectionAdapters::MysqlAdapter",
        "ActiveRecord::ConnectionAdapters::Mysql2Adapter"
      ].freeze

      private

      def migration_version
        major = ::Rails::VERSION::MAJOR
        if major >= 5
          "[#{major}.#{::Rails::VERSION::MINOR}]"
        end
      end

      def mysql?
        MYSQL_ADAPTERS.include?(::ActiveRecord::Base.connection.class.name)
      end

      def table_options
        if mysql?
          ', { options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci" }'
        else
          ""
        end
      end
    end
  end
end
