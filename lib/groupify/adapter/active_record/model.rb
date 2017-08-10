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
          @group_class_name = opts[:group_class_name] || Groupify.group_class_name
          include Groupify::ActiveRecord::GroupMember
        end

        def acts_as_named_group_member(opts = {})
          include Groupify::ActiveRecord::NamedGroupMember
        end

        def acts_as_group_membership(opts = {})
          include Groupify::ActiveRecord::GroupMembership
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Groupify::ActiveRecord::Model
