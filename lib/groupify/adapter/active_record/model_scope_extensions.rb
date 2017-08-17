module Groupify
  module ActiveRecord
    module ModelScopeExtensions
      def self.build_for(parent_type, options = {})
        module_name = "#{parent_type.to_s.classify}ScopeExtensions"

        const_get(module_name.to_sym)
      rescue NameError
        # convert :group_member and :named_group_member
        parent_type = :member unless parent_type == :group
        child_type = parent_type == :group ? :member : :group

        new_module = Module.new do
          # This is an ambiguous call when a class implements both group and
          # member. We make a guess, but default to assuming it's a member.
          # See `detect_result_type_for` for more details.
          def as(*membership_types)
            if detect_result_type_for(current_scope || self) == :member
              with_memberships_for_member{as(membership_types)}
            else
              with_memberships_for_group{as(membership_types)}
            end
          end

          base_methods = %Q(
            def with_memberships_for_#{parent_type}(opts = {}, &group_membership_filter)
              criteria = []
              criteria << joins(:group_memberships_as_#{parent_type})
              criteria << opts[:criteria] if opts[:criteria]
              criteria << Groupify.group_membership_klass.instance_eval(&group_membership_filter) if block_given?

              # merge all criteria together
              criteria.compact.reduce(:merge)
            end
          )

          child_methods = %Q(
            def with_#{child_type}s(child_or_children)
              scope = if child_or_children.is_a?(::ActiveRecord::Base)
                        # single child
                        with_memberships_for_#{parent_type}(criteria: child_or_children.group_memberships_as_#{child_type})
                      else
                        with_memberships_for_#{parent_type}{for_#{child_type}s(child_or_children)}
                      end

              if block_given?
                scope = scope.with_memberships_for_#{parent_type}(&group_membership_filter)
              end

              scope
            end

            def without_#{child_type}s(children)
              with_memberships_for_#{parent_type}{not_for_#{child_type}s(children)}
            end
          )

          class_eval(base_methods)
          class_eval(child_methods) if options[:child_methods]

        protected

          # Determines what the result type is for the scope (group or member).
          # If it implements both, then we see if we can infer things from joins.
          # Defaults to assume it's a group.
          def detect_result_type_for(scope)
            case scope
            when ::ActiveRecord::Associations::CollectionProxy, ::ActiveRecord::AssociationRelation
              return scope.source_name.to_sym
            when Class # assume inherits ::ActiveRecord::Base
              klass = scope
            when ::ActiveRecord::Base
              klass = scope.class
            when ::ActiveRecord::Relation
              klass = scope.klass
            end

            types = []
            types << :group  if klass < Group
            types << :member if klass < GroupMember || klass < NamedGroupMember

            return types.first if types.one?

            if scope.is_a?(::ActiveRecord::Relation) && scope.joins_values.first == :group_memberships_as_group
              :group
            else
              :member
            end
          end
        end

        const_set(module_name, new_module)
      end
    end
  end
end
