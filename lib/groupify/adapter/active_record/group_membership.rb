module Groupify
  module ActiveRecord

    # Join table that tracks which members belong to which groups
    #
    # Usage:
    #    class GroupMembership < ActiveRecord::Base
    #        acts_as_group_membership
    #        ...
    #    end
    #
    module GroupMembership
      extend ActiveSupport::Concern

      included do
        attr_accessible(:member, :group, :group_name, :membership_type, :as) if ActiveSupport::VERSION::MAJOR < 4

        belongs_to :member, :polymorphic => true
        belongs_to :group
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
      end
    end
  end
end
