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
    begin
      klass = association_name.to_s.classify.constantize
    rescue StandardError => ex
      puts "Error: #{ex.inspect}"
      #puts ex.backtrace
    end

    if !association_name.is_a?(Symbol) && klass
      association_name = klass.model_name.plural
    end

    [klass, association_name.to_sym]
  end
end

require 'groupify/railtie' if defined?(Rails)
