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

        has_group :groups
      end

      def in_group?(group, opts = {})
        return false unless group.present?

        criteria = group_memberships_as_member.merge(group.group_memberships_as_group)
        criteria = criteria.as(opts[:as]) if opts[:as]
        criteria.exists?
      end

      def in_any_group?(*groups)
        opts = groups.extract_options!

        groups.flatten.any?{ |group| in_group?(group, opts) }
      end

      def in_all_groups?(*groups)
        opts = groups.extract_options!

        groups.flatten.to_set.subset? self.groups.as(opts[:as]).to_set
      end

      def in_only_groups?(*groups)
        opts = groups.extract_options!

        groups.flatten.to_set == self.groups.as(opts[:as]).to_set
      end

      def shares_any_group?(other, opts = {})
        in_any_group?(other.groups, opts)
      end

      module ClassMethods
        def as(membership_type)
          memberships_merge{as(membership_type)}
        end

        def in_group(group)
          return none unless group.present?

          memberships_merge(group.group_memberships_as_group).distinct
        end

        def in_any_group(*groups)
          groups = groups.flatten
          return none unless groups.present?

          memberships_merge{for_groups(groups)}.distinct
        end

        def in_all_groups(*groups)
          groups = groups.flatten
          return none unless groups.present?

          group_id_column = ActiveRecord.quote(Groupify.group_membership_klass, 'group_id')
          group_type_column = ActiveRecord.quote(Groupify.group_membership_klass, 'group_type')
          # Count distinct on ID and type combo
          concatenated_columns =  case connection.adapter_name.downcase
                                  when /sqlite/
                                    "#{group_id_column} || #{group_type_column}"
                                  else #when /mysql/, /postgres/, /pg/
                                    "CONCAT(#{group_id_column}, #{group_type_column})"
                                  end

          memberships_merge{for_groups(groups)}.
            group(ActiveRecord.quote(self, 'id')).
            having("COUNT(DISTINCT #{concatenated_columns}) = ?", groups.count).
            distinct
        end

        def in_only_groups(*groups)
          groups = groups.flatten
          return none unless groups.present?

          in_all_groups(*groups).
            where.not(id: in_other_groups(*groups).select(ActiveRecord.quote(self, 'id'))).
            distinct
        end

        def in_other_groups(*groups)
          memberships_merge{not_for_groups(groups)}
        end

        def shares_any_group(other)
          in_any_group(other.groups)
        end

        def has_group(name, source_type = nil, options = {})
          if source_type.is_a?(Hash)
            options, source_type = source_type, nil
          end

          source_type ||= @group_class_name

          has_many name.to_sym, ->{ distinct }, {
            through: :group_memberships_as_member,
            source: :group,
            source_type: source_type,
            extend: Groupify::ActiveRecord::AssociationExtensions
          }.merge(options.slice :class_name)
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
