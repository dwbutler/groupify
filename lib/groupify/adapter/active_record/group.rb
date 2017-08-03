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
        def has_members(*names)
          names.flatten.each do |name|
            has_member(name)
          end
        end

        def has_member(name, options = {})
          klass_name = options[:class_name]

          if klass_name.nil?
            klass, association_name = Groupify.infer_class_and_association_name(name)
          else
            klass = klass_name.to_s.classify.constantize
            association_name = name.to_sym
          end

          associate_member_class(klass, association_name)
        end

        # Merge two groups. The members of the source become members of the destination, and the source is destroyed.
        def merge!(source_group, destination_group)
          # Ensure that all the members of the source can be members of the destination
          invalid_member_classes = (source_group.member_classes - destination_group.member_classes)
          invalid_member_classes.each do |klass|
            if klass.memberships_merge(source_group.group_memberships_as_group).count > 0
              raise ArgumentError.new("#{source_group.class} has members that cannot belong to #{destination_group.class}")
            end
          end

          source_group.transaction do
            source_group.group_memberships_as_group.update_all(group_id: destination_group.id, group_type: destination_group.class.base_class.name)
            source_group.destroy
          end
        end

      protected

        def associate_member_class(member_klass, association_name = nil)
          (@member_klasses ||= Set.new) << member_klass

          define_member_association(member_klass, association_name)

          if member_klass == default_member_class
            define_member_association(member_klass, :members)
          end

          member_klass
        end

        def define_member_association(member_klass, association_name = nil)
          association_name ||= member_klass.model_name.plural.to_sym
          source_type = member_klass.base_class.to_s

          has_many association_name,
            ->{ distinct },
            through: :group_memberships_as_group,
            source: :member,
            source_type: source_type,
            extend: Groupify::ActiveRecord::AssociationExtensions
        end

        def memberships_merge(merge_criteria, &group_membership_filter)
          query = joins(:group_memberships_as_group)
          query = query.merge(merge_criteria) if merge_criteria
          query = query.merge(Groupify.group_membership_klass.instance_eval(&group_membership_filter)) if block_given?
          query
        end
      end
    end
  end
end
