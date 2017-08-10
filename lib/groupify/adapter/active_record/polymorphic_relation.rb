module Groupify
  module ActiveRecord
    class PolymorphicRelation < PolymorphicCollection
      include CollectionExtensions

      def initialize(parent_proxy, &group_membership_filter)
        @parent_proxy = parent_proxy

        super(parent_proxy.child_type) do
          query = merge(parent_proxy.memberships_association)
          query = query.instance_eval(&group_membership_filter) if block_given?
          query
        end
      end

      def as(membership_type)
        @collection = super

        self
      end

      attr_reader :collection, :parent_proxy

    protected

      def default_association
        @parent_proxy.children_association
      end
    end
  end
end
