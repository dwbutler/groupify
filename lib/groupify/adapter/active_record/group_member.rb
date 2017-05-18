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
        unless respond_to?(:group_memberships_as_member)
          has_many :group_memberships_as_member,
                   as: :member,
                   autosave: true,
                   dependent: :destroy,
                   class_name: Groupify.group_membership_class_name
        end

        has_group :groups
      end

      module GroupAssociationExtensions
        def as(membership_type)
          return self unless membership_type
          merge(Groupify.group_membership_klass.as(membership_type))
        end

        def <<(*args)
          opts = {silent: true}.merge args.extract_options!
          membership_type = opts[:as]
          groups = args.flatten
          return self unless groups.present?

          member = proxy_association.owner
          member.__send__(:clear_association_cache)

          to_add_directly = []
          to_add_with_membership_type = []

          # first prepare changes
          groups.each do |group|
            # add to collection without membership type
            to_add_directly << group unless include?(group)
            # add a second entry for the given membership type
            if membership_type
              membership = group.group_memberships_as_group.where(member_id: member.id, member_type: member.class.base_class.to_s, membership_type: membership_type).first_or_initialize
              to_add_with_membership_type << membership unless membership.persisted?
            end
            group.__send__(:clear_association_cache)
          end

          # then validate changes
          list_to_validate = to_add_directly + to_add_with_membership_type

          list_to_validate.each do |item|
            next if item.valid?

            if opts[:silent]
              return false
            else
              raise RecordInvalid.new(item)
            end
          end

          # then persist changes
          super(to_add_directly)

          to_add_with_membership_type.each do |membership|
            membership.group.group_memberships_as_group << membership
            membership.group.__send__(:clear_association_cache)
          end

          self
        end
        alias_method :add, :<<

        def delete(*args)
          opts = args.extract_options!
          groups = args.flatten

          if opts[:as]
            proxy_association.owner.group_memberships_as_member.where(group_id: groups.map(&:id)).as(opts[:as]).delete_all
          else
            super(*groups)
          end

          groups.each{|group| group.__send__(:clear_association_cache)}
        end

        def destroy(*args)
          opts = args.extract_options!
          groups = args.flatten

          if opts[:as]
            proxy_association.owner.group_memberships_as_member.where(group_id: groups.map(&:id)).as(opts[:as]).destroy_all
          else
            super(*groups)
          end

          groups.each{|group| group.__send__(:clear_association_cache)}
        end
      end

      def in_group?(group, opts={})
        return false unless group.present?
        criteria = {group_id: group.id}

        if opts[:as]
          criteria.merge!(membership_type: opts[:as])
        end

        group_memberships_as_member.exists?(criteria)
      end

      def in_any_group?(*args)
        opts = args.extract_options!
        groups = args

        groups.flatten.each do |group|
          return true if in_group?(group, opts)
        end
        return false
      end

      def in_all_groups?(*args)
        opts = args.extract_options!
        groups = args.flatten

        groups.to_set.subset? self.groups.as(opts[:as]).to_set
      end

      def in_only_groups?(*args)
        opts = args.extract_options!
        groups = args.flatten

        groups.to_set == self.groups.as(opts[:as]).to_set
      end

      def shares_any_group?(other, opts={})
        in_any_group?(other.groups, opts)
      end

      module ClassMethods
        def as(membership_type)
          joins(:group_memberships_as_member).merge(Groupify.group_membership_klass.as(membership_type))
        end

        def in_group(group)
          return none unless group.present?

          joins(:group_memberships_as_member).merge(Groupify.group_membership_klass.where(group_id: group.id)).distinct
        end

        def in_any_group(*groups)
          groups = groups.flatten
          return none unless groups.present?

          joins(:group_memberships_as_member).
            merge(Groupify.group_membership_klass.where(group_id: groups)).
            distinct
        end

        def in_all_groups(*groups)
          groups = groups.flatten
          return none unless groups.present?

          joins(:group_memberships_as_member).
              group("#{quoted_table_name}.#{connection.quote_column_name('id')}").
            merge(Groupify.group_membership_klass.where(group_id: groups)).
            having("COUNT(DISTINCT #{Groupify.group_membership_klass.quoted_table_name}.#{connection.quote_column_name('group_id')}) = ?", groups.count).
              distinct
        end

        def in_only_groups(*groups)
          groups = groups.flatten
          return none unless groups.present?

          in_all_groups(*groups).
            where.not(id: in_other_groups(*groups).select("#{quoted_table_name}.#{connection.quote_column_name('id')}")).
            distinct
        end

        def in_other_groups(*groups)
          joins(:group_memberships_as_member).
            merge(Groupify.group_membership_klass.where.not(group_id: groups))
        end

        def shares_any_group(other)
          in_any_group(other.groups)
        end

        def has_group(name, options = {})
          has_many name.to_sym, ->{ distinct }, {
            through: :group_memberships_as_member,
            source: :group,
            source_type: @group_class_name,
            extend: Groupify::ActiveRecord::GroupAssociationExtensions
          }.merge(options.slice :class_name)
        end
      end
    end
  end
end
