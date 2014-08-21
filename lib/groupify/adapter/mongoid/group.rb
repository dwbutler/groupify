module Groupify
  module Mongoid

    # Usage:
    #    class Group
    #      include Mongoid::Document
    #
    #      acts_as_group, :members => [:users]
    #      ...
    #    end
    #
    #   group.add(member)
    #
    module Group
      extend ActiveSupport::Concern

      included do
        @default_member_class = nil
        @member_klasses ||= Set.new
      end

      # def members
      #   self.class.default_member_class.any_in(:group_ids => [self.id])
      # end

      def member_classes
        self.class.member_classes
      end

      def add(*args)
        opts = args.extract_options!
        membership_type = opts[:as]
        members = args.flatten
        return unless members.present?

        members.each do |member|
          member.groups << self
          membership = member.group_memberships.find_or_initialize_by(as: membership_type)
          membership.groups << self
          membership.save!
        end
      end

      # Merge a source group into this group.
      def merge!(source)
        self.class.merge!(source, self)
      end

      module ClassMethods
        def with_member(member)
          member.groups
        end

        def default_member_class
          @default_member_class ||= User rescue false
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
            if klass.in(group_ids: [source_group.id]).count > 0
              raise ArgumentError.new("#{source_group.class} has members that cannot belong to #{destination_group.class}")
            end
          end

          source_group.member_classes.each do |klass|
            klass.in(group_ids: [source_group.id]).update_all(:$set => {:"group_ids.$" => destination_group.id})

            if klass.relations['group_memberships']
              if ::Mongoid::VERSION > "4"
                klass.in(:"group_memberships.group_ids" => [source_group.id]).add_to_set(:"group_memberships.$.group_ids" => destination_group.id)
                klass.in(:"group_memberships.group_ids" => [source_group.id]).pull(:"group_memberships.$.group_ids" => source_group.id)
              else
                klass.in(:"group_memberships.group_ids" => [source_group.id]).add_to_set(:"group_memberships.$.group_ids", destination_group.id)
                klass.in(:"group_memberships.group_ids" => [source_group.id]).pull(:"group_memberships.$.group_ids", source_group.id)
              end
            end
          end

          source_group.delete
        end

        protected

        def register(member_klass)
          (@member_klasses ||= Set.new) << member_klass
          associate_member_class(member_klass)
          member_klass
        end

        module MemberAssociationExtensions
          def as(membership_type)
            return self unless membership_type
            where(:group_memberships.elem_match => { as: membership_type.to_s, group_ids: [base.id] })
          end

          def destroy(*args)
            delete(*args)
          end

          def delete(*args)
            opts = args.extract_options!
            members = args

            if opts[:as]
              members.each do |member|
                member.group_memberships.as(opts[:as]).first.groups.delete(base)
              end
            else
              members.each do |member|
                member.group_memberships.in(groups: base).each do |membership|
                  membership.groups.delete(base)
                end
              end

              super(*members)
            end
          end
        end

        def associate_member_class(member_klass)
          association_name = member_klass.name.to_s.pluralize.underscore.to_sym

          has_many association_name, class_name: member_klass.to_s, dependent: :nullify, foreign_key: 'group_ids', extend: MemberAssociationExtensions

          if member_klass == default_member_class
            has_many :members, class_name: member_klass.to_s, dependent: :nullify, foreign_key: 'group_ids', extend: MemberAssociationExtensions
          end
        end
      end
    end
  end
end
