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
        has_many :group_memberships,
                 dependent: :destroy,
                 as: :group,
                 class_name: Groupify.group_membership_class_name

      end

      def member_classes
        self.class.member_classes
      end

      def add(*args)
        opts = args.extract_options!
        membership_type = opts[:as]
        members = args.flatten
        return unless members.present?

        self.send(:clear_association_cache)

        members.each do |member|
          member.groups << self unless member.groups.include?(self)
          if membership_type
            member.group_memberships.where(group_id: id, group_type: self.class.model_name.to_s, membership_type: membership_type).first_or_create!
          end
          member.send(:clear_association_cache)
        end
      end

      # Merge a source group into this group.
      def merge!(source)
        self.class.merge!(source, self)
      end

      module ClassMethods
        def with_member(member)
          #joins(:group_memberships).where(:group_memberships => {:member_id => member.id, :member_type => member.class.to_s})
          member.groups
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
        def has_members(name)
          klass = name.to_s.classify.constantize
          register(klass)
        end

        # Merge two groups. The members of the source become members of the destination, and the source is destroyed.
        def merge!(source_group, destination_group)
          # Ensure that all the members of the source can be members of the destination
          invalid_member_classes = (source_group.member_classes - destination_group.member_classes)
          invalid_member_classes.each do |klass|
            if klass.joins(:group_memberships).where(:group_memberships => {:group_id => source_group.id}).count > 0
              raise ArgumentError.new("#{source_group.class} has members that cannot belong to #{destination_group.class}")
            end
          end

          source_group.transaction do
            source_group.group_memberships.update_all(:group_id => destination_group.id)
            source_group.destroy
          end
        end

        protected

        def register(member_klass)
          (@member_klasses ||= Set.new) << member_klass

          associate_member_class(member_klass)

          member_klass
        end

        module MemberAssociationExtensions
          def as(membership_type)
            where(group_memberships: {membership_type: membership_type})
          end

          def delete(*args)
            opts = args.extract_options!
            members = args

            if opts[:as]
              proxy_association.owner.group_memberships.
                  where(member_id: members.map(&:id), member_type: proxy_association.reflection.options[:source_type]).
                  as(opts[:as]).
                  delete_all
            else
              super(*members)
            end
          end

          def destroy(*args)
            opts = args.extract_options!
            members = args

            if opts[:as]
              proxy_association.owner.group_memberships.
                  where(member_id: members.map(&:id), member_type: proxy_association.reflection.options[:source_type]).
                  as(opts[:as]).
                  destroy_all
            else
              super(*members)
            end
          end
        end

        def associate_member_class(member_klass)
          define_member_association(member_klass)

          if member_klass == default_member_class
            define_member_association(member_klass, :members)
          end
        end

        def define_member_association(member_klass, association_name = nil)
          association_name ||= member_klass.model_name.plural.to_sym
          source_type = member_klass.base_class

          if ActiveSupport::VERSION::MAJOR > 3
            has_many association_name,
                     ->{ uniq },
                     through: :group_memberships,
                     source: :member,
                     source_type: source_type,
                     extend: MemberAssociationExtensions
          else
            has_many association_name,
                     uniq: true,
                     through: :group_memberships,
                     source: :member,
                     source_type: source_type,
                     extend: MemberAssociationExtensions
          end

          define_method(association_name) do |*args|
            opts = args.extract_options!
            membership_type = opts[:as]
            if membership_type.present?
              super().as(membership_type)
            else
              super()
            end
          end
        end
      end
    end
  end
end
