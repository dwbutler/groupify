require 'groupify/adapter/active_record/association_extensions'

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
        @default_group_class_name = nil
        @default_groups_association_name = nil

        has_many :group_memberships_as_member,
          as: :member,
          autosave: true,
          dependent: :destroy,
          class_name: Groupify.group_membership_class_name
      end

      def as_member
        @as_member ||= ParentProxy.new(self, :member)
      end

      def polymorphic_groups(&group_membership_filter)
        PolymorphicRelation.new(as_member, &group_membership_filter)
      end

      # returns `nil` membership type with results
      def membership_types_for_group(group)
        group_memberships_as_member.
          for_groups([group]).
          select(:membership_type).
          distinct.
          pluck(:membership_type).
          sort_by(&:to_s)
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
        def as(membership_type)
          member_finder.as(membership_type)
        end

        def in_group(group)
          group.present? ? member_finder.with_children(group).distinct : none
        end

        def in_any_group(*groups)
          groups.flatten!
          groups.present? ? member_finder.with_children(groups).distinct : none
        end

        def in_all_groups(*groups)
          groups.flatten!

          return none unless groups.present?

          id, type = ActiveRecord.quote('group_id'), ActiveRecord.quote('group_type')
          # Count distinct on ID and type combo
          concatenated_columns = ActiveRecord.is_db?('sqlite') ? "#{id} || #{type}" : "CONCAT(#{id}, #{type})"

          member_finder.with_children(groups).
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
          member_finder.without_children(groups)
        end

        def shares_any_group(other)
          in_any_group(other.polymorphic_groups)
        end

        def has_groups(*association_names, &extension)
          association_names.flatten.each do |association_name|
            has_group(association_name, &extension)
          end
        end

        def default_group_class_name
          @default_group_class_name ||= Groupify.group_class_name
        end

        def default_group_class_name=(klass)
          @default_group_class_name = klass
        end

        def default_groups_association_name
          @default_groups_association_name ||= Groupify.groups_association_name
        end

        def default_groups_association_name=(name)
          @default_groups_association_name = name && name.to_sym
        end

        def has_group(association_name, opts = {}, &extension)
          ActiveRecord.create_children_association(self, association_name,
            opts.merge(
              through: :group_memberships_as_member,
              source: :group,
              default_base_class: default_group_class_name
            ),
            &extension
          )

          self
        end

        def member_finder
          @member_finder ||= ParentQueryBuilder.new(self, :member)
        end
      end
    end
  end
end
