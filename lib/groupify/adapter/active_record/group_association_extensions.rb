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
        proxy_association.owner.group_memberships_as_member.where(group_id: group.id, group_type: group.class.base_class.to_s, membership_type: membership_type)
      end

      def find_for_destruction(membership_type, *groups)
        proxy_association.owner.group_memberships_as_member.where(group_id: groups.map(&:id)).as(membership_type)
      end
    end
  end
end
