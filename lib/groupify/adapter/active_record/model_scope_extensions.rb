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
          base_methods = %Q(
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

          child_methods = %Q(
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

          class_eval(base_methods)
          class_eval(child_methods) if options[:child_methods]
        end

        const_set(module_name, new_module)
      end
    end
  end
end
