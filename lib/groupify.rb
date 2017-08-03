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

  def self.infer_class_and_association_name(name)
    klass = name.to_s.classify.constantize rescue nil

    association_name =  if name.is_a?(Symbol)
                          name
                        elsif klass
                          klass.model_name.plural.to_sym
                        else
                          name.plural.to_sym
                        end

    [klass, association_name]
  end
end

require 'groupify/railtie' if defined?(Rails)
