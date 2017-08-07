require 'active_record'
require 'set'

module Groupify
  module ActiveRecord
    require 'groupify/adapter/active_record/model'

    autoload :Group, 'groupify/adapter/active_record/group'
    autoload :GroupMember, 'groupify/adapter/active_record/group_member'
    autoload :GroupMembership, 'groupify/adapter/active_record/group_membership'
    autoload :PolymorphicCollection, 'groupify/adapter/active_record/polymorphic_collection'
    autoload :PolymorphicRelation, 'groupify/adapter/active_record/polymorphic_relation'
    autoload :ParentProxy, 'groupify/adapter/active_record/parent_proxy'
    autoload :ParentQueryBuilder, 'groupify/adapter/active_record/parent_query_builder'
    autoload :NamedGroupCollection, 'groupify/adapter/active_record/named_group_collection'
    autoload :NamedGroupMember, 'groupify/adapter/active_record/named_group_member'

    def self.is_db?(*strings)
      strings.any?{ |string| ::ActiveRecord::Base.connection.adapter_name.downcase.include?(string) }
    end

    def self.quote(column_name, model_class = Groupify.group_membership_klass)
      "#{model_class.quoted_table_name}.#{::ActiveRecord::Base.connection.quote_column_name(column_name)}"
    end

    # Pass in record, class, or string
    def self.base_class_name(model_class, &default_base_class)
      return if model_class.nil?

      if model_class.is_a?(::ActiveRecord::Base)
        model_class = model_class.class
      elsif !(model_class.is_a?(Class) && model_class < ::ActiveRecord::Base)
        model_class = model_class.to_s.constantize
      end

      model_class.base_class.name
    rescue NameError
      return base_class_name(yield) if block_given?
      return model_class.to_s if Groupify.ignore_base_class_inference_errors

      raise
    end
  end
end
