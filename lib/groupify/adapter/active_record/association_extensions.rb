require 'groupify/adapter/active_record/collection_extensions'

module Groupify
  module ActiveRecord
    module AssociationExtensions
      include CollectionExtensions

      def parent_proxy
        @parent_proxy ||= ParentProxy.new(
                            proxy_association.owner,
                            proxy_association.through_reflection.name == :group_memberships_as_group ? :group : :member
                          )
      end

    protected

      # Throw an exception here when adding direction to an association
      # because when adding the children to the parent this won't
      # happen because the group membership is polymorphic.
      def add_children(children, opts = {})
        children.each do |child|
          proxy_association.__send__(:raise_on_type_mismatch!, child)
        end

        super
      end
    end
  end
end

def build_extension_module(module_name, parent_type, options = {})
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

build_extension_module("GroupScopeExtensions", :group, child_methods: true)
build_extension_module("GroupMemberScopeExtensions", :member, child_methods: true)
build_extension_module("NamedGroupMemberScopeExtensions", :member)
