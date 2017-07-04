require 'groupify/adapter/active_record/member_association_extensions'

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
        opts = members.extract_options!

        members.flatten.each do |member|
          member.groups.add(self, opts)
        end

        self
      end

      # Merge a source group into this group.
      def merge!(source)
        self.class.merge!(source, self)
      end

      module ClassMethods
        def with_member(member)
          #member.groups
          joins(:group_memberships_as_group).
          merge(member.group_memberships_as_member).
          extending(Groupify::ActiveRecord::GroupMember::GroupAssociationExtensions)
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
          Array.wrap(names.flatten).each do |name|
            has_member name
          end
        end

        def has_member(name, options = {})
          klass_name = options[:class_name]

          if klass_name.nil?
            klass = name.to_s.classify.constantize
            association_name = name.is_a?(Symbol) ? name : klass.model_name.plural.to_sym
          else
            klass = klass_name.to_s.classify.constantize
            association_name = name.to_sym
          end

          register(klass, association_name)
        end

        # Merge two groups. The members of the source become members of the destination, and the source is destroyed.
        def merge!(source_group, destination_group)
          # Ensure that all the members of the source can be members of the destination
          invalid_member_classes = (source_group.member_classes - destination_group.member_classes)
          invalid_member_classes.each do |klass|
            if klass.joins(:group_memberships_as_member).merge(source_group.group_memberships_as_group).count > 0
              raise ArgumentError.new("#{source_group.class} has members that cannot belong to #{destination_group.class}")
            end
          end

          source_group.transaction do
            source_group.group_memberships_as_group.update_all(group_id: destination_group.id, group_type: destination_group.class.base_class.name)
            source_group.destroy
          end
        end

        protected

        def register(member_klass, association_name = nil)
          (@member_klasses ||= Set.new) << member_klass

          associate_member_class(member_klass, association_name)

          member_klass
        end

        module MemberAssociationExtensions
          def as(membership_type)
            merge(Groupify.group_membership_klass.as(membership_type))
          end

          def <<(*args)
            opts = {silent: true}.merge args.extract_options!
            membership_type = opts[:as]
            members = args.flatten
            return self unless members.present?

            group = proxy_association.owner
            group.__send__(:clear_association_cache)

            to_add_directly = []
            to_add_with_membership_type = []

            # first prepare changes
            members.each do |member|
              # add to collection without membership type
              to_add_directly << member unless include?(member)
              # add a second entry for the given membership type
              if membership_type
                membership = member.group_memberships_as_member.merge(group.group_memberships_as_group).as(membership_type).first_or_initialize
                to_add_with_membership_type << membership unless membership.persisted?
              end
              member.__send__(:clear_association_cache)
            end

            # then validate changes
            list_to_validate = to_add_directly + to_add_with_membership_type

            list_to_validate.each do |item|
              next if item.valid?

              if opts[:silent]
                return false
              else
                raise RecordInvalid.new(item)
              end
            end

            # then persist changes
            super(to_add_directly)

            to_add_with_membership_type.each do |membership|
              membership.member.group_memberships_as_member << membership
              membership.member.__send__(:clear_association_cache)
            end

            self
          end
          alias_method :add, :<<

          def delete(*args)
            opts = args.extract_options!
            members = args

            if opts[:as]
              proxy_association.owner.group_memberships_as_group.
                  where(member_id: members, member_type: proxy_association.reflection.options[:source_type]).
                  as(opts[:as]).
                  delete_all
            else
              super(*members)
            end

            members.each{|member| member.__send__(:clear_association_cache)}
          end

          def destroy(*args)
            opts = args.extract_options!
            members = args

            if opts[:as]
              proxy_association.owner.group_memberships_as_group.
                  where(member_id: members.map(&:id), member_type: proxy_association.reflection.options[:source_type]).
                  as(opts[:as]).
                  destroy_all
            else
              super(*members)
            end

            members.each{|member| member.__send__(:clear_association_cache)}
          end
        end

        def associate_member_class(member_klass, association_name = nil)
          define_member_association(member_klass, association_name)

          if member_klass == default_member_class
            define_member_association(member_klass, :members)
          end
        end

        def define_member_association(member_klass, association_name = nil)
          association_name ||= member_klass.model_name.plural.to_sym
          source_type = member_klass.base_class

          has_many association_name,
                   ->{ distinct },
                   through: :group_memberships_as_group,
                   source: :member,
                   source_type: source_type.to_s,
                   extend: MemberAssociationExtensions
        end
      end
    end
  end
end
