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
        def named(group_name=nil)
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
          for_polymorphic(:group, groups, not: true)
        end

        def for_members(members)
          for_polymorphic(:member, members)
        end

        def criteria_for_groups(groups)
          criteria_for_polymorphic(:group, groups)
        end

        def criteria_for_members(members)
          criteria_for_polymorphic(:member, members)
        end

        def for_polymorphic(name, records, options = {})
          if records.is_a?(Array)
            if options[:not]
              where.not(criteria_for_polymorphic(name, records))
            else
              where(criteria_for_polymorphic(name, records))
            end
          elsif records.is_a?(::ActiveRecord::Relation)
            merge(records)
          elsif records
            merge(records.__send__(:"group_memberships_as_#{name}"))
          else
            self
          end
        end

        def criteria_for_polymorphic(prefix, records)
          records_by_base_class = records.group_by{ |record| record.class.base_class }
          klass = respond_to?(:proxy_association) ? proxy_association.klass : self

          criteria_values = records_by_base_class.map do |base_class, records|
            klass.arel_table.grouping([
              klass.arel_table[:"#{prefix}_type"].eq(base_class.name),
              klass.arel_table[:"#{prefix}_id"].in(records.map(&:id))
            ].reduce(:and))
          end

          criteria_values.reduce(:or)
        end
      end
    end
  end
end
