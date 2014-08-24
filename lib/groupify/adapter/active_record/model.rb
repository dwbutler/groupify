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
            member_klasses.each do |member_klass|
              has_members(member_klass)
            end
          end
        end

        def acts_as_group_member(opts = {})
          @group_class_name = opts[:class_name] || 'Group'
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
