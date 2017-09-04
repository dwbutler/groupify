module Groupify
  module ActiveRecord
    # This class acts as an association facade building on `PolymorphicCollection`
    # by implementing the Groupify helper methods on this collection. This class
    # also mimics an association by tracking the parent record that owns the
    # association.
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

      def as(*membership_types)
        @collection = @collection.as(membership_types)

        self
      end
    end
  end
end
