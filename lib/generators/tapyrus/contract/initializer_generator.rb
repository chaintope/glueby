module Tapyrus
  module Contract
    class InitializerGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def create_initializer_file
        template "initializer.rb.erb", "config/initializers/tapyrus_contract.rb"
      end
    end
  end
end
