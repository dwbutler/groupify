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

          if (member_klass = opts.delete :default_members)
            self.default_member_class = member_klass.to_s.classify.constantize
          end

          if (member_klasses = opts.delete :members)
            has_members(member_klasses)
          end
        end

        def acts_as_group_member(opts = {})
          include Groupify::ActiveRecord::GroupMember

          if default_group_class_name = opts[:group_class_name] || opts[:default_group_class_name] || Groupify.group_class_name
            self.default_group_class = default_group_class_name.to_s.classify.constantize
            belongs_to_group(default_group_class_name)
          end

          if group_class_names = opts.delete(:groups)
            belongs_to_groups(group_class_names)
          end
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
