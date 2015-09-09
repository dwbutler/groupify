module Groupify
  module Mongoid
    class ModelGenerator < Rails::Generators::Base
      source_root File.expand_path("../templates", __FILE__)

      def copy_group_model_file
        copy_file "group.rb", "app/models/group.rb"
      end
    end
  end
end
