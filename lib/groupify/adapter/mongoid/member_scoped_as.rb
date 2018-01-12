module Groupify
  module Mongoid

    module MemberScopedAs
      extend ActiveSupport::Concern

      module ClassMethods
        def as(membership_type)
          criteria = self.criteria

          return criteria unless membership_type.present?

          group_ids = criteria.selector["group_ids"]
          named_groups = criteria.selector["named_groups"]

          # If filtering by groups or named groups, merge into the group membership criteria
          if group_ids || named_groups
            elem_match = {as: membership_type}
            elem_match.merge!(group_ids: group_ids) if group_ids
            elem_match.merge!(named_groups: named_groups) if named_groups

            criteria = where(:group_memberships.elem_match => elem_match)
            criteria.selector.delete("group_ids")
            criteria.selector.delete("named_groups")
          else
            criteria = where(:"group_memberships.as" => membership_type)
          end

          criteria
        end
      end
    end
  end
end
