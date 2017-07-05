require 'groupify/adapter/active_record/association_extensions'

module Groupify
  module ActiveRecord
    module GroupAssociationExtensions
      include AssociationExtensions

    protected

      def association_parent_type
        :member
      end

      def find_memberships_for(group, membership_type)
        proxy_association.owner.group_memberships_as_member.
          merge(group.group_memberships_as_group).
          as(membership_type)
      end

      def find_for_destruction(membership_type, groups)
        proxy_association.owner.group_memberships_as_member.
          where(group: groups).as(membership_type)
      end
    end
  end
end
