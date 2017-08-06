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

      def polymorphic_members(&group_membership_filter)
        PolymorphicRelation.new(self, :group, &group_membership_filter)
      end

      def member_classes
        self.class.member_classes
      end

      def add(*members)
        opts = members.extract_options!.merge(parent_type: :group)

        ActiveRecord.add_children_to_parent(self, members.flatten, opts)

        self
      end

      # Merge a source group into this group.
      def merge!(source)
        self.class.merge!(source, self)
      end

      module ClassMethods
        def with_member(member)
          memberships_merge(member.group_memberships_as_member).
            extending(Groupify::ActiveRecord::AssociationExtensions)
        end

        def default_member_class
          @default_member_class ||= (User rescue false)
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
          association_class, association_name = Groupify.infer_class_and_association_name(association_name)
          model_klass = options[:class_name] || association_class
          member_klass = model_klass.to_s.constantize

          (@member_klasses ||= Set.new) << member_klass

          unless options[:source_type]
            # only try to look up base class if needed - can cause circular dependency issue
            source_type = ActiveRecord.base_class_name(member_klass) || member_klass || default_member_class
          end

          has_many association_name, ->{ distinct }, {
              through: :group_memberships_as_group,
              source: :member,
              source_type: source_type,
              extend: Groupify::ActiveRecord::AssociationExtensions
            }.merge(options)

        rescue NameError => ex
          raise "Can't infer base class for #{member_klass.inspect}: #{ex.message}. Try specifying the `:source_type` option such as `has_member(#{association_name.inspect}, source_type: 'BaseClass')` in case there is a circular dependency."
        end

        # Merge two groups. The members of the source become members of the destination, and the source is destroyed.
        def merge!(source_group, destination_group)
          # Ensure that all the members of the source can be members of the destination
          invalid_member_classes = source_group.member_classes - destination_group.member_classes
          invalid_found = invalid_member_classes.any?{ |klass| klass.memberships_merge(source_group.group_memberships_as_group).count > 0 }

          if invalid_found
            raise ArgumentError.new("#{source_group.class} has members that cannot belong to #{destination_group.class}")
          end

          source_group.transaction do
            source_group.group_memberships_as_group.update_all(
              group_id: destination_group.id,
              group_type: ActiveRecord.base_class_name(destination_group)
            )
            source_group.destroy
          end
        end

      protected

        def memberships_merge(merge_criteria = nil, &group_membership_filter)
          ActiveRecord.memberships_merge(self, parent_type: :group, criteria: merge_criteria, filter: group_membership_filter)
        end
      end
    end
  end
end
