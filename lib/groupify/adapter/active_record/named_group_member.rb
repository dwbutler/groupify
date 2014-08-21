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
        unless respond_to?(:group_memberships)
          has_many :group_memberships, :as => :member, :autosave => true, :dependent => :destroy
        end
      end

      def named_groups
        @named_groups ||= NamedGroupCollection.new(self)
      end

      def named_groups=(groups)
        groups.each do |group|
          self.named_groups << group
        end
      end

      def in_named_group?(named_group, opts={})
        named_groups.include?(named_group, opts)
      end

      def in_any_named_group?(*args)
        opts = args.extract_options!
        named_groups = args.flatten
        named_groups.each do |named_group|
          return true if in_named_group?(named_group, opts)
        end
        return false
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

      def shares_any_named_group?(other, opts={})
        in_any_named_group?(other.named_groups.to_a, opts)
      end

      module ClassMethods
        def as(membership_type)
          joins(:group_memberships).where(group_memberships: {membership_type: membership_type})
        end

        def in_named_group(named_group)
          return none unless named_group.present?

          joins(:group_memberships).where(group_memberships: {group_name: named_group}).uniq
        end

        def in_any_named_group(*named_groups)
          named_groups.flatten!
          return none unless named_groups.present?

          joins(:group_memberships).where(group_memberships: {group_name: named_groups.flatten}).uniq
        end

        def in_all_named_groups(*named_groups)
          named_groups.flatten!
          return none unless named_groups.present?

          joins(:group_memberships).
              group(:"group_memberships.member_id").
              where(:group_memberships => {:group_name => named_groups}).
              having("COUNT(DISTINCT group_memberships.group_name) = #{named_groups.count}").
              uniq
        end

        def in_only_named_groups(*named_groups)
          named_groups.flatten!
          return none unless named_groups.present?

          joins(:group_memberships).
              group("group_memberships.member_id").
              having("COUNT(DISTINCT group_memberships.group_name) = #{named_groups.count}").
              uniq
        end

        def shares_any_named_group(other)
          in_any_named_group(other.named_groups.to_a)
        end
      end
    end
  end
end
