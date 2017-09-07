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
    autoload :NamedGroupCollection, 'groupify/adapter/active_record/named_group_collection'
    autoload :NamedGroupMember, 'groupify/adapter/active_record/named_group_member'

    def self.is_db?(*strings)
      strings.any?{ |string| ::ActiveRecord::Base.connection.adapter_name.downcase.include?(string) }
    end

    def self.quote(column_name, model_class = nil)
      model_class = Groupify.group_membership_klass unless model_class.is_a?(Class)
      "#{model_class.quoted_table_name}.#{model_class.connection.quote_column_name(column_name)}"
    end

    def self.prepare_concat(*columns)
      options = columns.extract_options!
      columns.flatten!

      if options[:quote]
        columns = columns.map{ |column| quote(column, options[:quote]) }
      end

      is_db?('sqlite') ? columns.join(' || ') : "CONCAT(#{columns.join(', ')})"
    end

    def self.prepare_distinct(*columns)
      options = columns.extract_options!
      columns.flatten!

      if options[:quote]
        columns = columns.map{ |column| quote(column, options[:quote]) }
      end

      # Workaround to "group by" multiple columns in PostgreSQL
      is_db?('postgres') ? "ON (#{columns.join(', ')}) *" : columns
    end

    # Pass in record, class, or string
    def self.base_class_name(model_class, default_base_class = nil)
      return if model_class.nil?

      if model_class.is_a?(::ActiveRecord::Base)
        model_class = model_class.class
      elsif !(model_class.is_a?(Class) && model_class < ::ActiveRecord::Base)
        model_class = model_class.to_s.constantize
      end

      model_class.base_class.name
    rescue NameError
      return base_class_name(default_base_class) if default_base_class
      return model_class.to_s if Groupify.ignore_base_class_inference_errors

      raise
    end

    def self.create_children_association(klass, association_name, opts = {}, &extension)
      association_class, association_name = Groupify.infer_class_and_association_name(association_name)
      default_base_class = opts.delete(:default_base_class)
      model_klass = opts[:class_name] || association_class || default_base_class

      # only try to look up base class if needed - can cause circular dependency issue
      opts[:source_type] ||= ActiveRecord.base_class_name(model_klass, default_base_class)
      opts[:class_name]  ||= model_klass.to_s unless opts[:source_type].to_s == model_klass.to_s

      require 'groupify/adapter/active_record/association_extensions'

      klass.has_many association_name, ->{ distinct }, {
        extend: Groupify::ActiveRecord::AssociationExtensions
      }.merge(opts), &extension

      model_klass

    rescue NameError => ex
      re = /has_(group|member)/
      line = ex.backtrace.find{ |i| i =~ re }

      message = ["Can't infer base class for #{parent_klass.inspect}: #{ex.message}. Try specifying the `:source_type` option"]
      message << "such as `#{line.match(re)[0]}(#{association_name.inspect}, source_type: 'BaseClass')`" if line
      message << "in case there is a circular dependency."

      raise message.join(' ')
    end

    # Returns `false` if this is not an association
    def self.group_memberships_association_name_for_association(scope)
      case scope
      when ::ActiveRecord::Associations::CollectionProxy, ::ActiveRecord::AssociationRelation
        scope_reflection = scope.proxy_association.reflection

        loop do
          break if scope_reflection.nil?

          case scope_reflection.name
          when :group_memberships_as_group, :group_memberships_as_member
            break
          end

          scope_reflection = scope_reflection.through_reflection
        end

        scope_reflection && scope_reflection.name
      else
        false
      end
    end

    class InvalidAssociationError < StandardError
    end

    def self.check_group_memberships_for_association!(scope)
      association_name = group_memberships_association_name_for_association(scope)

      return association_name unless association_name.nil?

      association_example = "#{scope.proxy_association.owner.class}##{scope.proxy_association.reflection.name}"
      raise InvalidAssociationError, "You can't use the #{association_example} association because it does not go through the group memberships association."
    end
  end
end
