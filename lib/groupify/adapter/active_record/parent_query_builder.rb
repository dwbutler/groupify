module Groupify
  module ActiveRecord
    class ParentQueryBuilder < SimpleDelegator
      def initialize(scope, parent_type)
        @scope = scope.all.extending(Groupify::ActiveRecord::AssociationExtensions)
        @parent_type = parent_type
        @child_type = parent_type == :group ? :member : :group

        super(@scope)
      end

      def as(membership_type)
        with_memberships{as(membership_type)}
      end

      def with_children(child_or_children)
        scope = if child_or_children.is_a?(::ActiveRecord::Base)
                  # single child
                  with_memberships(criteria: child_or_children.__send__(:"group_memberships_as_#{@child_type}"))
                else
                  method_name = :"for_#{@child_type}s"
                  with_memberships{__send__(method_name, child_or_children)}
                end

        if block_given?
          scope = scope.with_memberships(&group_membership_filter)
        end

        scope
      end

      def without_children(children)
        method_name = :"not_for_#{@child_type}s"
        with_memberships{__send__(method_name, children)}
      end

      def with_memberships(opts = {}, &group_membership_filter)
        criteria = []
        criteria << @scope.joins(:"group_memberships_as_#{@parent_type}")
        criteria << opts[:criteria] if opts[:criteria]
        criteria << Groupify.group_membership_klass.instance_eval(&group_membership_filter) if block_given?

        # merge all criteria together
        wrap criteria.compact.reduce(:merge)
      end

    protected

      def wrap(scope)
        self.class.new(scope, @parent_type)
      end
    end
  end
end
