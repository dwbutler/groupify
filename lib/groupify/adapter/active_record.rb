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
      "#{model_class.quoted_table_name}.#{model_class.connection.quote_column_name(column_name)}"
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

    def self.create_children_association(klass, association_name, opts = {})
      association_class, association_name = Groupify.infer_class_and_association_name(association_name)
      default_base_class = opts.delete(:default_base_class)
      model_klass = opts[:class_name] || association_class || default_base_class

      # only try to look up base class if needed - can cause circular dependency issue
      opts[:source_type] ||= ActiveRecord.base_class_name(model_klass, default_base_class)

      klass.has_many association_name, ->{ distinct }, {
        extend: Groupify::ActiveRecord::AssociationExtensions
      }.merge(opts)

      model_klass

    rescue NameError => ex
      re = /has_(group|member)/
      line = ex.backtrace.find{ |i| i =~ re }

      message = ["Can't infer base class for #{parent_klass.inspect}: #{ex.message}. Try specifying the `:source_type` option"]
      message << "such as `#{line.match(re)[0]}(#{association_name.inspect}, source_type: 'BaseClass')`" if line
      message << "in case there is a circular dependency."

      raise message.join(' ')
    end

    def self.build_scope_module(module_name, parent_type, options = {})
      child_type = parent_type == :group ? :member : :group

      new_module = Module.new do
        class_eval %Q(
          def as(membership_type)
            with_memberships{as(membership_type)}
          end

          def with_memberships(opts = {}, &group_membership_filter)
            criteria = []
            criteria << joins(:group_memberships_as_#{parent_type})
            criteria << opts[:criteria] if opts[:criteria]
            criteria << Groupify.group_membership_klass.instance_eval(&group_membership_filter) if block_given?

            # merge all criteria together
            criteria.compact.reduce(:merge)
          end
        )

        if options[:child_methods]
          class_eval %Q(
            def with_#{child_type}s(child_or_children)
              scope = if child_or_children.is_a?(::ActiveRecord::Base)
                        # single child
                        with_memberships(criteria: child_or_children.group_memberships_as_#{child_type})
                      else
                        with_memberships{for_#{child_type}s(child_or_children)}
                      end

              if block_given?
                scope = scope.with_memberships(&group_membership_filter)
              end

              scope
            end

            def without_#{child_type}s(children)
              with_memberships{not_for_#{child_type}s(children)}
            end

            def delete(*records)
              remove_children(records, :destroy, records.extract_options![:as])
            end

            def destroy(*records)
              remove_children(records, :destroy, records.extract_options![:as])
            end

            # Defined to create alias methods before
            # the association is extended with this module
            def <<(*children)
              opts = children.extract_options!.merge(exception_on_invalidation: false)
              add_children(children.flatten, opts)
            end

            def add(*children)
              opts = children.extract_options!.merge(exception_on_invalidation: true)
              add_children(children.flatten, opts)
            end

          )
        end
      end

      Groupify::ActiveRecord.const_set(module_name, new_module)
    end

  end
end
