module Groupify
  module ActiveRecord
    module Model
      extend ActiveSupport::Concern

      included do
        require 'groupify/adapter/active_record/model_scope_extensions'
        require 'groupify/adapter/active_record/model_membership_extensions'

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
          extend Groupify::ActiveRecord::ModelScopeExtensions.build_for(:group, child_methods: true)

          configure_group!(opts)
        end

        def acts_as_group_member(opts = {})
          include Groupify::ActiveRecord::GroupMember
          extend Groupify::ActiveRecord::ModelScopeExtensions.build_for(:group_member, child_methods: true)

          configure_group_member!(opts)
        end

        def acts_as_named_group_member(opts = {})
          include Groupify::ActiveRecord::NamedGroupMember
          extend Groupify::ActiveRecord::ModelScopeExtensions.build_for(:named_group_member)
        end

        def acts_as_group_membership(opts = {})
          include Groupify::ActiveRecord::GroupMembership
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Groupify::ActiveRecord::Model
