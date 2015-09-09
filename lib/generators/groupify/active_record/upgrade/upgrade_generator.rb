require "rails/generators/migration"
require "rails/generators/active_record"
require "generators/groupify/active_record/next_migration_version"

module Groupify
  module ActiveRecord
    class UpgradeGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      extend NextMigrationVersion

      source_root File.expand_path("../templates", __FILE__)

      def create_migration_file
        migration_template "upgrade_migration.rb", "db/migrate/add_group_type_to_group_memberships.rb"
      end

      def self.next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number dirname
      end
    end
  end
end
