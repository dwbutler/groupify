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
        has_many :group_memberships_as_member,
          as: :member,
          autosave: true,
          dependent: :destroy,
          class_name: Groupify.group_membership_class_name

        has_group Groupify.groups_association_name.to_sym,
          source_type: ActiveRecord.base_class_name(@group_class_name),
          class_name: @group_class_name
      end

      def member_proxy
        @member_proxy ||= ParentProxy.new(self, :member)
      end

      def polymorphic_groups(&group_membership_filter)
        PolymorphicRelation.new(member_proxy, &group_membership_filter)
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
          member_scope.as(membership_type)
        end

        def in_group(group)
          group.present? ? member_scope.merge_children(group).distinct : none
        end

        def in_any_group(*groups)
          groups.flatten!
          groups.present? ? member_scope.merge_children(groups).distinct : none
        end

        def in_all_groups(*groups)
          groups.flatten!

          return none unless groups.present?

          id, type = ActiveRecord.quote('group_id'), ActiveRecord.quote('group_type')
          # Count distinct on ID and type combo
          concatenated_columns = ActiveRecord.is_db?('sqlite') ? "#{id} || #{type}" : "CONCAT(#{id}, #{type})"

          member_scope.merge_children(groups).
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
          member_scope.merge_children_without(groups)
        end

        def shares_any_group(other)
          in_any_group(other.polymorphic_groups)
        end

        def has_groups(*association_names)
          association_names.flatten.each do |association_name|
            has_group(association_name)
          end
        end

        def has_group(association_name, options = {})
          ActiveRecord.create_children_association(self, association_name,
            options.merge(
              through: :group_memberships_as_member,
              source: :group,
              default_base_class: @group_class_name
            )
          )

          self
        end

        def member_scope
          @member_scope ||= ParentQueryBuilder.new(self, :member)
        end
      end
    end
  end
end
