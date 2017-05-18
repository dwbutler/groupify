module Groupify
  module ActiveRecord
    module GroupAssociationExtensions
      include AssociationExtensions

      def <<(*children)
        add_children_to_parent(:group, *children, &super)
      end
      alias_method :add, :<<

    protected

      def find_memberships_for_adding_children(group, member, membership_type)
        group.group_memberships_as_group.where(member_id: member.id, member_type: member.class.base_class.to_s, membership_type: membership_type)
      end

      def find_for_destruction(membership_type, *groups)
        proxy_association.owner.group_memberships_as_member.where(group_id: groups.map(&:id)).as(membership_type)
      end
    end
  end
end
