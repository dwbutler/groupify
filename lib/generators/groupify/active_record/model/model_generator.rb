module Groupify
  module ActiveRecord
    class ModelGenerator < Rails::Generators::Base
      source_root File.expand_path("../templates", __FILE__)

      def copy_group_model_file
        copy_file "group.rb", "app/models/group.rb"
      end

      def copy_group_membership_model_file
        copy_file "group_membership.rb", "app/models/group_membership.rb"
      end
    end
  end
end
