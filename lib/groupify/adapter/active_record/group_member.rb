module Groupify
  module ActiveRecord

    # Usage:
    #    class User < ActiveRecord::Base
    #        groupify :group_member
    #        ...
    #    end
    #
    #    user.groups << group
    #
    module GroupMember
      extend ActiveSupport::Concern

      included do
        include Groupify::ActiveRecord::ModelExtensions.build_for(:group_member)
        extend Groupify::ActiveRecord::ModelScopeExtensions.build_for(:group_member, child_methods: true)
      end

      def in_group?(group, opts = {})
        return false unless group.present?

        group_memberships_as_member.
          for_groups(group).
          as(opts[:as]).
          exists?
      end

      def in_any_group?(*groups)
        opts = groups.extract_options!
        groups.flatten.any?{ |group| in_group?(group, opts) }
      end

      def in_all_groups?(*groups)
        membership_type = groups.extract_options![:as]
        groups.flatten.to_set.subset? self.polymorphic_groups.as(membership_type).to_set
      end

      def in_only_groups?(*groups)
        membership_type = groups.extract_options![:as]
        groups.flatten.to_set == self.polymorphic_groups.as(membership_type).to_set
      end

      def shares_any_group?(other, opts = {})
        in_any_group?(other.polymorphic_groups, opts)
      end

      module ClassMethods
        def in_group(group)
          group.present? ? with_groups(group).distinct : none
        end

        def in_any_group(*groups)
          groups.flatten!
          groups.present? ? with_groups(groups).distinct : none
        end

        def in_all_groups(*groups)
          groups.flatten!

          return none unless groups.present?

          # Count distinct on ID and type combo
          concatenated_columns = ActiveRecord.prepare_concat('group_id', 'group_type', quote: true)

          with_groups(groups).
            group(ActiveRecord.quote('id', self)).
            having("COUNT(DISTINCT #{concatenated_columns}) = ?", groups.count).
            distinct
        end

        def in_only_groups(*groups)
          groups.flatten!

          return none unless groups.present?

          in_all_groups(*groups).
            where.not(id: in_other_groups(*groups).select(ActiveRecord.quote('id', self))).
            distinct
        end

        def in_other_groups(*groups)
          without_groups(groups)
        end

        def shares_any_group(other)
          in_any_group(other.polymorphic_groups)
        end
      end
    end
  end
end
