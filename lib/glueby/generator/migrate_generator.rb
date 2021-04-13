module Glueby
  module Generator
    module MigrateGenerator
      module ClassMethod
        def next_migration_number(dirname)
          # ::ActiveRecord::Migration.next_migration_number(number)
          # ::ActiveRecord::Generators::Base.next_migration_number(dirname)
          next_migration_number = current_migration_number(dirname) + 1
          ::ActiveRecord::Migration.next_migration_number(next_migration_number)
        end
      end

      MYSQL_ADAPTERS = [
        "ActiveRecord::ConnectionAdapters::MysqlAdapter",
        "ActiveRecord::ConnectionAdapters::Mysql2Adapter"
      ].freeze

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
          ', :options => "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci"'
        else
          ""
        end
      end
    end
  end
end