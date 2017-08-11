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
          membership_type.present? ? where(membership_type: membership_type.to_s) : all
        end

        def polymorphic_groups
          PolymorphicCollection.new(:group)
        end

        def polymorphic_members
          PolymorphicCollection.new(:member)
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

        def for_polymorphic(source, records, opts = {})
          case records
          when Array
            where(build_polymorphic_criteria_for(source, records))
          when ::ActiveRecord::Relation
            all.merge(records)
          when ::ActiveRecord::Base
            all.merge(records.__send__(:"group_memberships_as_#{source}"))
          else
            all
          end
        end

        # Build criteria to search on ID grouped by base class type.
        # This is for polymorphic associations where the ID may be from
        # different tables.
        def build_polymorphic_criteria_for(source, records)
          records_by_base_class  = records.group_by{ |record| ActiveRecord.base_class_name(record) }
          id_column, type_column = arel_table[:"#{source}_id"], arel_table[:"#{source}_type"]

          criteria = records_by_base_class.map do |type, grouped_records|
            arel_table.grouping(
                type_column.eq(type).
              and(
                id_column.in(grouped_records.map(&:id))
              )
            )
          end

          # Generates something like:
          #   (group_type = `Group` AND group_id IN (?)) OR (group_type = `Team` AND group_id IN(?))
          criteria.reduce(:or)
        end
      end
    end
  end
end
