module Groupify
  module ActiveRecord
    class PolymorphicRelation < PolymorphicCollection
      include CollectionExtensions

      def initialize(parent, parent_type, &group_membership_filter)
        @collection_parent, @collection_parent_type = parent, parent_type
        @child_type = parent_type == :group ? :member : :group

        super(@child_type) do |query|
          query = query.merge(parent.__send__(:"group_memberships_as_#{parent_type}"))
          query = query.instance_eval(&group_membership_filter) if block_given?
          query
        end
      end

      def as(membership_type)
        @query = super

        self
      end

      # When trying to create a new record for this collection,
      # create it on the `member.default_groups` or `group.default_members`
      # association.
      def_delegators :default_association, :build, :create, :create!

    protected

      attr_reader :collection_parent, :collection_parent_type

      def collection
        @query
      end

      def default_association
        @collection_parent.__send__(Groupify.__send__(:"#{@child_type}s_association_name"))
      end
    end
  end
end
