require 'groupify/adapter/active_record/association_extensions'

module Groupify
  module ActiveRecord

    # Usage:
    #    class Group < ActiveRecord::Base
    #        groupify :group, members: [:users]
    #        ...
    #    end
    #
    #   group.add(member)
    #
    module Group
      extend ActiveSupport::Concern

      included do
        include Groupify::ActiveRecord::ModelMembershipExtensions.build_for(:group)
      end

      def add(*members)
        opts = members.extract_options!

        add_members(members.flatten, opts)
      end

      # Merge a source group into this group.
      def merge!(source)
        self.class.merge!(source, self)
      end

      module ClassMethods
        def with_member(member)
          with_members(member)
        end

        # Merge two groups. The members of the source become members of the destination, and the source is destroyed.
        def merge!(source_group, destination_group)
          # Ensure that all the members of the source can be members of the destination
          invalid_member_classes = source_group.member_classes - destination_group.member_classes
          invalid_found = invalid_member_classes.any?{ |klass| klass.with_groups(source_group).count > 0 }

          if invalid_found
            raise ArgumentError.new("#{source_group.class} has members that cannot belong to #{destination_group.class}")
          end

          source_group.transaction do
            source_group.group_memberships_as_group.update_all(
              group_id: destination_group.id,
              group_type: ActiveRecord.base_class_name(destination_group)
            )

            destination_group.__send__(:clear_association_cache)
            source_group.__send__(:clear_association_cache)
            source_group.destroy
          end
        end
      end
    end
  end
end
