module Groupify
  module ActiveRecord

    # Usage:
    #    class User < ActiveRecord::Base
    #        acts_as_named_group_member
    #        ...
    #    end
    #
    #    user.named_groups << :admin
    #
    module NamedGroupMember
      extend ActiveSupport::Concern

      included do
        unless respond_to?(:group_memberships_as_member)
          has_many :group_memberships_as_member,
                   as: :member,
                   autosave: true,
                   dependent: :destroy,
                   class_name: Groupify.group_membership_class_name
        end
      end

      def named_groups
        @named_groups ||= NamedGroupCollection.new(self)
      end

      def named_groups=(named_groups)
        named_groups.each do |named_group|
          self.named_groups << named_group
        end
      end

      def in_named_group?(named_group, opts = {})
        named_groups.include?(named_group, opts)
      end

      def in_any_named_group?(*args)
        opts = args.extract_options!
        named_groups = args.flatten
        named_groups.any?{ |named_group| in_named_group?(named_group, opts) }
      end

      def in_all_named_groups?(*args)
        opts = args.extract_options!
        named_groups = args.flatten.to_set
        named_groups.subset? self.named_groups.as(opts[:as]).to_set
      end

      def in_only_named_groups?(*args)
        opts = args.extract_options!
        named_groups = args.flatten.to_set
        named_groups == self.named_groups.as(opts[:as]).to_set
      end

      def shares_any_named_group?(other, opts = {})
        in_any_named_group?(other.named_groups.to_a, opts)
      end

      module ClassMethods
        def as(membership_type)
          memberships_merge(Groupify.group_membership_klass.as(membership_type))
        end

        def in_named_group(named_group)
          return none unless named_group.present?

          memberships_merge{where(group_name: named_group)}.distinct
        end

        def in_any_named_group(*named_groups)
          named_groups.flatten!
          return none unless named_groups.present?

          memberships_merge{where(group_name: named_groups.flatten)}.distinct
        end

        def in_all_named_groups(*named_groups)
          named_groups.flatten!
          return none unless named_groups.present?

          memberships_merge{where(group_name: named_groups)}.
              group(ActiveRecord.quote(self, 'id')).
              having("COUNT(DISTINCT #{ActiveRecord.quote(Groupify.group_membership_klass, 'group_name')}) = ?", named_groups.count).
              distinct
        end

        def in_only_named_groups(*named_groups)
          named_groups.flatten!
          return none unless named_groups.present?

          in_all_named_groups(*named_groups).
            where.not(id: in_other_named_groups(*named_groups).select(ActiveRecord.quote(self, 'id'))).
            distinct
        end

        def in_other_named_groups(*named_groups)
          memberships_merge{where.not(group_name: named_groups)}
        end

        def shares_any_named_group(other)
          in_any_named_group(other.named_groups.to_a)
        end

        def memberships_merge(merge_criteria = nil, &group_membership_filter)
          query = joins(:group_memberships_as_member)
          query = query.merge(merge_criteria) if merge_criteria
          query = query.merge(Groupify.group_membership_klass.instance_eval(&group_membership_filter)) if block_given?
          query
        end
      end
    end
  end
end
