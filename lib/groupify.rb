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
end

require 'groupify/railtie' if defined?(Rails)
