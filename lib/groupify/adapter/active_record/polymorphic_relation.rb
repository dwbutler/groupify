module Groupify
  module ActiveRecord
    class PolymorphicRelation < PolymorphicCollection
      include CollectionExtensions

      attr_reader :collection, :parent_proxy

      def initialize(parent_proxy, &group_membership_filter)
        @parent_proxy = parent_proxy

        super(parent_proxy.child_type) do
          query = merge(parent_proxy.memberships)
          query = query.instance_eval(&group_membership_filter) if block_given?
          query
        end
      end

      def as(membership_type)
        @collection = @collection.as(membership_type)

        self
      end
    end
  end
end
