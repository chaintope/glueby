
require 'active_record'

module Glueby
  module AR
    autoload :SystemInformation, 'glueby/active_record/system_information'

    def transaction(isolation: nil)
      options = { joinable: false, requires_new: true }

      adapter_type = ActiveRecord::Base.connection.adapter_name.downcase

      # SQLite3 does not support transaction isolation level READ COMMITTED.
      if isolation == :read_committed && adapter_type == 'mysql2'
        options[:isolation] = :read_committed
      end

      ActiveRecord::Base.transaction(**options) do
        yield
      end
    end

    module_function :transaction
  end
end