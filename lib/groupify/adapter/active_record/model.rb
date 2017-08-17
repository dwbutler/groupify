module Groupify
  module ActiveRecord
    module Model
      extend ActiveSupport::Concern

      included do
        # Define a scope that returns nothing.
        # This is built into ActiveRecord 4, but not 3
        unless self.class.respond_to? :none
          def self.none
            where(arel_table[:id].eq(nil).and(arel_table[:id].not_eq(nil)))
          end
        end
      end

      module ClassMethods
        def groupify(type, opts = {})
          send("acts_as_#{type}", opts)
        end

        def acts_as_group(opts = {})
          include Groupify::ActiveRecord::Group
          extend Groupify::ActiveRecord::GroupScopeExtensions

          # Get defaults from parent class for STI
          self.default_member_class_name = Groupify.superclass_fetch(self, :default_member_class_name, Groupify.member_class_name)
          self.default_members_association_name = Groupify.superclass_fetch(self, :default_members_association_name, Groupify.members_association_name)

          if (member_association_names = opts.delete :members)
            has_members(member_association_names)
          end

          if (default_members = opts.delete :default_members)
            self.default_member_class_name = default_members.to_s.classify
            # Only use as the association name if none specified (backwards-compatibility)
            self.default_members_association_name ||= default_members
          end

          if default_members_association_name
            has_member(default_members_association_name,
              source_type: ActiveRecord.base_class_name(default_member_class_name),
              class_name: default_member_class_name
            )
          end
        end

        def acts_as_group_member(opts = {})
          include Groupify::ActiveRecord::GroupMember
          extend Groupify::ActiveRecord::GroupMemberScopeExtensions

          # Get defaults from parent class for STI
          self.default_group_class_name = Groupify.superclass_fetch(self, :default_group_class_name, Groupify.group_class_name)
          self.default_groups_association_name = Groupify.superclass_fetch(self, :default_groups_association_name, Groupify.groups_association_name)

          if (group_association_names = opts.delete :groups)
            has_groups(group_association_names)
          end

          if (default_groups = opts.delete :default_groups)
            self.default_group_class_name = default_groups.to_s.classify
            self.default_groups_association_name ||= default_groups
          end

          # Deprecated: for backwards-compatibility
          if (group_class_name = opts.delete :group_class_name)
            self.default_group_class_name = group_class_name
          end

          if default_groups_association_name
            has_group default_groups_association_name,
              source_type: ActiveRecord.base_class_name(default_group_class_name),
              class_name: default_group_class_name
          end
        end

        def acts_as_named_group_member(opts = {})
          include Groupify::ActiveRecord::NamedGroupMember
          extend Groupify::ActiveRecord::NamedGroupMemberScopeExtensions
        end

        def acts_as_group_membership(opts = {})
          include Groupify::ActiveRecord::GroupMembership
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Groupify::ActiveRecord::Model
