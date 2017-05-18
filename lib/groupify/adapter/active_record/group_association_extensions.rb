module Groupify
  module ActiveRecord
    module GroupAssociationExtensions
      include AssociationExtensions

      def <<(*children)
        add_children_to_parent(:group, *children)
      end
      alias_method :add, :<<

    protected

      def find_for_destruction(membership_type, *groups)
        proxy_association.owner.group_memberships_as_member.where(group_id: groups.map(&:id)).as(membership_type)
      end
    end
  end
end
