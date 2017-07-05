require 'groupify/adapter/active_record/association_extensions'

module Groupify
  module ActiveRecord
    module MemberAssociationExtensions
      include AssociationExtensions

    protected

      def association_parent_type
        :group
      end

      def find_memberships_for(member, membership_type)
        proxy_association.owner.group_memberships_as_group.
          merge(member.group_memberships_as_member).
          as(membership_type)
      end

      def find_for_destruction(membership_type, members)
        proxy_association.owner.group_memberships_as_group.
          where(member: members).
          as(membership_type)
      end
    end
  end
end
