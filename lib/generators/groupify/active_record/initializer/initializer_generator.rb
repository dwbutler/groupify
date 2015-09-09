module Groupify
  module ActiveRecord
    class InitializerGenerator < Rails::Generators::Base
      source_root File.expand_path("../templates", __FILE__)

      def copy_initializer
        copy_file "initializer.rb", "config/initializers/groupify.rb"
      end
    end
  end
end
