module Groupify
  module Mongoid

    module MemberScopedAs
      extend ActiveSupport::Concern

      module ClassMethods
        def as(membership_type)
          group_ids = criteria.selector["group_ids"]
          named_groups = criteria.selector["named_groups"]
          criteria = self.criteria

          # If filtering by groups or named groups, merge into the group membership criteria
          if group_ids || named_groups
            elem_match = {as: membership_type}

            if group_ids
              elem_match.merge!(group_ids: group_ids)
            end

            if named_groups
              elem_match.merge!(named_groups: named_groups)
            end

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
