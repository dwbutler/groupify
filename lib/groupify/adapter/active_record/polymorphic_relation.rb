module Groupify
  module ActiveRecord
    class PolymorphicRelation < PolymorphicCollection
      include CollectionExtensions

      attr_reader :collection

      def initialize(owner, source_name, &group_membership_filter)
        @owner = owner
        parent_type = source_name == :group ? :member : :group

        super(source_name) do
          query = merge(owner.__send__(:"group_memberships_as_#{parent_type}"))
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
