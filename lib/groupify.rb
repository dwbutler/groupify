require 'active_support'

module Groupify
  mattr_accessor :group_membership_class_name,
                 :group_class_name,
                 :member_class_name,
                 :members_association_name,
                 :groups_association_name,
                 :ignore_base_class_inference_errors,
                 :ignore_association_class_inference_errors

  self.group_membership_class_name = 'GroupMembership'
  self.group_class_name = nil # 'Group'
  self.member_class_name = nil # 'User'
  # Set to `false` if default association should not be created
  self.members_association_name = false # :members
  # Set to `false` if default association should not be created
  self.groups_association_name = false # :groups
  self.ignore_base_class_inference_errors = true
  self.ignore_association_class_inference_errors = true

  def self.configure
    yield self
  end

  def self.configure_legacy_defaults!
    configure do |config|
      config.group_class_name  = 'Group'
      config.member_class_name = 'User'

      config.groups_association_name  = :groups
      config.members_association_name = :members
    end
  end

  def self.group_membership_klass
    group_membership_class_name.constantize
  end

  # Get the value of the superclass method.
  # Return a default value if the result is `nil`.
  def self.superclass_fetch(klass, method_name, default_value = nil, &default_value_builder)
    # recursively try to get a non-nil value
    while (klass = klass.superclass).method_defined?(method_name)
      superclass_value = klass.__send__(method_name)

      return superclass_value unless superclass_value.nil?
    end

    block_given? ? yield : default_value
  end

  def self.infer_class_and_association_name(association_name)
    begin
      klass = association_name.to_s.classify.constantize
    rescue NameError => ex
      puts "Error: #{ex.inspect}"
      #puts ex.backtrace

      if Groupify.ignore_association_class_inference_errors
        klass = association_name.to_s.classify
      end
    end

    if !association_name.is_a?(Symbol) && klass.is_a?(Class)
      association_name = klass.model_name.plural
    end

    [klass, association_name.to_sym]
  end

  def self.clean_membership_types(*membership_types)
    membership_types.flatten.compact.map(&:to_s).reject(&:empty?)
  end
end

require 'groupify/railtie' if defined?(Rails)
