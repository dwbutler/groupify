require 'groupify/adapter/active_record/association_extensions'

module Groupify
  module ActiveRecord
    module GroupAssociationExtensions
      extend ActiveSupport::Concern
      include AssociationExtensions

      included do
        setup_alias_methods!
      end

    protected

      def association_parent_type
        :member
      end

      def find_memberships_for(group, membership_type)
        proxy_association.owner.group_memberships_as_member.where(group_id: group.id, membership_type: membership_type)
      end

      def find_for_destruction(membership_type, *groups)
        proxy_association.owner.group_memberships_as_member.where(group_id: groups.map(&:id)).as(membership_type)
      end
    end
  end
end
