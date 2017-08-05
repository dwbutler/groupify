require 'active_support'

module Groupify
  mattr_accessor :group_membership_class_name,
                 :group_class_name,
                 :ignore_base_class_inference_errors

  self.group_class_name = 'Group'
  self.group_membership_class_name = 'GroupMembership'
  self.ignore_base_class_inference_errors = true

  def self.configure
    yield self
  end

  def self.group_membership_klass
    group_membership_class_name.constantize
  end

  def self.infer_class_and_association_name(association_name)
    klass = association_name.to_s.classify.constantize rescue nil

    association_name =  if association_name.is_a?(Symbol)
                          association_name
                        elsif klass
                          klass.model_name.plural.to_sym
                        else
                          association_name.to_sym
                        end

    [klass, association_name]
  end
end

require 'groupify/railtie' if defined?(Rails)
