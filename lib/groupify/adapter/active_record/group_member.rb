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

        has_group :groups, source_type: ActiveRecord.base_class_name(@group_class_name)
      end

      def in_group?(group, opts = {})
        return false unless group.present?

        group_memberships_as_member.
          merge(group.group_memberships_as_group).
          as(opts[:as]).
          exists?
      end

      def in_any_group?(*groups)
        opts = groups.extract_options!
        groups.flatten.any?{ |group| in_group?(group, opts) }
      end

      def in_all_groups?(*groups)
        membership_type = groups.extract_options![:as]
        groups.flatten.to_set.subset? self.groups.as(membership_type).to_set
      end

      def in_only_groups?(*groups)
        membership_type = groups.extract_options![:as]
        groups.flatten.to_set == self.groups.as(membership_type).to_set
      end

      def shares_any_group?(other, opts = {})
        in_any_group?(other.groups, opts)
      end

      module ClassMethods
        def as(membership_type)
          memberships_merge{as(membership_type)}
        end

        def in_group(group)
          group.present? ? memberships_merge(group.group_memberships_as_group).distinct : none
        end

        def in_any_group(*groups)
          groups.flatten!
          groups.present? ? memberships_merge{for_groups(groups)}.distinct : none
        end

        def in_all_groups(*groups)
          groups.flatten!

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
          groups.flatten!

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

        def has_groups(*association_names)
          association_names.flatten.each do |association_name|
            has_group(association_name)
          end
        end

        def has_group(association_name, options = {})
          association_class, association_name = Groupify.infer_class_and_association_name(association_name)
          model_klass = options[:class_name] || association_class || @group_class_name

          unless options[:source_type]
            # only try to look up base class if needed - can cause circular dependency issue
            source_type = ActiveRecord.base_class_name(model_klass) || model_klass
          end

          has_many association_name.to_sym, ->{ distinct }, {
            through: :group_memberships_as_member,
            source: :group,
            source_type: source_type,
            extend: Groupify::ActiveRecord::AssociationExtensions
          }.merge(options)

        rescue NameError => ex
          raise "Can't infer base class for #{model_klass}: #{ex.message}. Try specifying the `:source_type` option such as `has_group(#{association_name.inspect}, source_type: 'BaseClass')` in case there is a circular dependency."
        end

        def memberships_merge(merge_criteria = nil, &group_membership_filter)
          ActiveRecord.memberships_merge(self, parent_type: :member, criteria: merge_criteria, filter: group_membership_filter)
        end
      end
    end
  end
end
