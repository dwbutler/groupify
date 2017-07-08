require 'groupify/adapter/active_record/group_association_extensions'

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

      def in_group?(group, opts={})
        return false unless group.present?

        criteria = group_memberships_as_member.merge(group.group_memberships_as_group)
        criteria = criteria.as(opts[:as]) if opts[:as]
        criteria.exists?
      end

      def in_any_group?(*args)
        opts = args.extract_options!
        groups = args.flatten

        groups.any?{ |group| in_group?(group, opts) }
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

          joins(:group_memberships_as_member).merge(group.group_memberships_as_group).distinct
        end

        def in_any_group(*groups)
          groups = groups.flatten
          return none unless groups.present?

          joins(:group_memberships_as_member).
            merge(Groupify.group_membership_klass.for_groups(groups)).
            distinct
        end

        def in_all_groups(*groups)
          groups = groups.flatten
          return none unless groups.present?

          group_id_column = Groupify.quoted_column_name_for(Groupify.group_membership_klass, 'group_id')
          group_type_column = Groupify.quoted_column_name_for(Groupify.group_membership_klass, 'group_type')
          # Count distinct on ID and type combo
          concatenated_columns =  case connection.adapter_name.downcase
                                  when /sqlite/
                                    "#{group_id_column} || #{group_type_column}"
                                  else #when /mysql/, /postgres/, /pg/
                                    "CONCAT(#{group_id_column}, #{group_type_column})"
                                  end

          joins(:group_memberships_as_member).
            group(Groupify.quoted_column_name_for(self, 'id')).
            merge(Groupify.group_membership_klass.for_groups(groups)).
            having("COUNT(DISTINCT #{concatenated_columns}) = ?", groups.count).
            distinct
        end

        def in_only_groups(*groups)
          groups = groups.flatten
          return none unless groups.present?

          in_all_groups(*groups).
            where.not(id: in_other_groups(*groups).select(Groupify.quoted_column_name_for(self, 'id'))).
            distinct
        end

        def in_other_groups(*groups)
          joins(:group_memberships_as_member).
            merge(Groupify.group_membership_klass.not_for_groups(groups))
        end

        def shares_any_group(other)
          in_any_group(other.groups)
        end

        def has_group(name, source_type = nil, options = {})
          if source_type.is_a?(Hash)
            options, source_type = source_type, nil
          end

          has_many name.to_sym, ->{ distinct }, {
            through: :group_memberships_as_member,
            source: :group,
            source_type: source_type || @group_class_name,
            extend: Groupify::ActiveRecord::GroupAssociationExtensions
          }.merge(options.slice :class_name)
        end
      end
    end
  end
end
