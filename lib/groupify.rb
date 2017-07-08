require 'active_support'

module Groupify
  mattr_accessor :group_membership_class_name,
                 :group_class_name

  self.group_class_name = 'Group'
  self.group_membership_class_name = 'GroupMembership'

  def self.configure
    yield self
  end

  def self.group_membership_klass
    group_membership_class_name.constantize
  end

  def self.quoted_column_name_for(model_class, column_name)
    "#{model_class.quoted_table_name}.#{::ActiveRecord::Base.connection.quote_column_name(column_name)}"
  end
end

require 'groupify/railtie' if defined?(Rails)
