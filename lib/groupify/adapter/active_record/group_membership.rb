module Groupify
  module ActiveRecord

    # Join table that tracks which members belong to which groups
    #
    # Usage:
    #    class GroupMembership < ActiveRecord::Base
    #        groupify :group_membership
    #        ...
    #    end
    #
    module GroupMembership
      extend ActiveSupport::Concern

      included do
        belongs_to :member, polymorphic: true
        belongs_to :group, polymorphic: true
      end

      def membership_type=(membership_type)
        self[:membership_type] = membership_type.to_s if membership_type.present?
      end

      def as=(membership_type)
        self.membership_type = membership_type
      end

      def as
        membership_type
      end

      module ClassMethods
        def named(group_name = nil)
          if group_name.present?
            where(group_name: group_name)
          else
            where("group_name IS NOT NULL")
          end
        end

        def as(membership_type)
          where(membership_type: membership_type)
        end

        def for_groups(groups)
          for_polymorphic(:group, groups)
        end

        def not_for_groups(groups)
          where.not(build_polymorphic_criteria_for(:group, groups))
        end

        def for_members(members)
          for_polymorphic(:member, members)
        end

        def not_for_members(groups)
          where.not(build_polymorphic_criteria_for(:member, members))
        end

        def for_polymorphic(source, records, options = {})
          case records
          when Array
            where(build_polymorphic_criteria_for(source, records))
          when ::ActiveRecord::Relation
            merge(records)
          when ::ActiveRecord::Base
            merge(records.__send__(:"group_memberships_as_#{source}"))
          else
            self
          end
        end

        # Build criteria to search on ID grouped by base class type.
        # This is for polymorphic associations where the ID may be from
        # different tables.
        def build_polymorphic_criteria_for(source, records)
          records_by_base_class = records.group_by{ |record| record.class.base_class.name }
          id_column, type_column = arel_table[:"#{source}_id"], arel_table[:"#{source}_type"]

          records_by_base_class.map{ |type, records| arel_table.grouping(type_column.eq(type).and(id_column.in(records.map(&:id)))) }.reduce(:or)
        end
      end
    end
  end
end
