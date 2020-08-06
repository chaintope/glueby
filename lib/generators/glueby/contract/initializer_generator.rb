module Glueby
  module Contract
    class InitializerGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def create_initializer_file
        template "initializer.rb.erb", "config/initializers/glueby.rb"
      end
    end
  end
end
