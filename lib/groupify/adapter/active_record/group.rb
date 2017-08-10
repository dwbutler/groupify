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
        @default_member_class = nil
        @member_klasses ||= Set.new

        has_many :group_memberships_as_group,
          dependent: :destroy,
          as: :group,
          class_name: Groupify.group_membership_class_name
      end

      def as_group
        @as_group ||= ParentProxy.new(self, :group)
      end

      def polymorphic_members(&group_membership_filter)
        PolymorphicRelation.new(as_group, &group_membership_filter)
      end

      def member_classes
        self.class.member_classes
      end

      def add(*members)
        opts = members.extract_options!

        as_group.add_children(members.flatten, opts)

        self
      end

      # Merge a source group into this group.
      def merge!(source)
        self.class.merge!(source, self)
      end

      module ClassMethods
        def with_member(member)
          group_finder.merge_children(member)
        end

        def default_member_class
          @default_member_class ||= (Groupify.member_class_name.constantize rescue nil)
        end

        def default_member_class=(klass)
          @default_member_class = klass
        end

        # Returns the member classes defined for this class, as well as for the super classes
        def member_classes
          (@member_klasses ||= Set.new).merge(superclass.method_defined?(:member_classes) ? superclass.member_classes : [])
        end

        # Define which classes are members of this group
        def has_members(*association_names)
          association_names.flatten.each do |association_name|
            has_member(association_name)
          end
        end

        def has_member(association_name, options = {})
          member_klass = ActiveRecord.create_children_association(self, association_name,
            options.merge(
              through: :group_memberships_as_group,
              source: :member,
              default_base_class: default_member_class
            )
          )

          (@member_klasses ||= Set.new) << member_klass.to_s.constantize

          self
        end

        # Merge two groups. The members of the source become members of the destination, and the source is destroyed.
        def merge!(source_group, destination_group)
          # Ensure that all the members of the source can be members of the destination
          invalid_member_classes = source_group.member_classes - destination_group.member_classes
          invalid_found = invalid_member_classes.any?{ |klass| klass.member_finder.merge_children(source_group).count > 0 }

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

        def group_finder
          @group_finder ||= ParentQueryBuilder.new(self, :group)
        end
      end
    end
  end
end
