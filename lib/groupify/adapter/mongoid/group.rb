module Groupify
  module Mongoid

    # Usage:
    #    class Group
    #      include Mongoid::Document
    #
    #      groupify :group, members: [:users]
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

      def add(*members)
        membership_type = members.extract_options![:as]
        members.flatten!

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
        def has_members(*association_names)
          association_names.flatten.each do |association_name|
            has_member(association_name)
          end
        end

        def has_member(association_name, options = {})
          association_class, association_name = Groupify.infer_class_and_association_name(association_name)
          model_klass = options[:class_name] || association_class

          define_member_association(model_klass.to_s.constantize, association_name, options)
        end

        # Merge two groups. The members of the source become members of the destination, and the source is destroyed.
        def merge!(source_group, destination_group)
          # Ensure that all the members of the source can be members of the destination
          invalid_member_classes = source_group.member_classes - destination_group.member_classes
          invalid_found = invalid_member_classes.any?{ |klass| klass.in(group_ids: [source_group.id]).count > 0 }

          if invalid_found
            raise ArgumentError.new("#{source_group.class} has members that cannot belong to #{destination_group.class}")
          end

          source_group.member_classes.each do |klass|
            klass.in(group_ids: [source_group.id]).update_all(:$set => {:"group_ids.$" => destination_group.id})

            if klass.relations['group_memberships']
              scope = klass.in(:"group_memberships.group_ids" => [source_group.id])
              criteria_for_add_to_set = {:"group_memberships.$.group_ids" => destination_group.id}
              criteria_for_pull = {:"group_memberships.$.group_ids" => source_group.id}

              if ::Mongoid::VERSION > "4"
                scope.add_to_set(criteria_for_add_to_set)
                scope.pull(criteria_for_pull)
              else
                scope.add_to_set(*criteria_for_add_to_set.to_a.flatten)
                scope.pull(*criteria_for_pull.to_a.flatten)
              end
            end
          end

          source_group.delete
        end

        protected

        module MemberAssociationExtensions
          def as(membership_type)
            membership_type.present? ? where(:group_memberships.elem_match => {as: membership_type, group_ids: [base.id]}) : self
          end

          def destroy(*members)
            delete(*members)
          end

          def delete(*members)
            membership_type = members.extract_options![:as]

            if membership_type.present?
              members.each do |member|
                member.group_memberships.as(membership_type).first.groups.delete(base)
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

        def define_member_association(member_klass, association_name, options = {})
          (@member_klasses ||= Set.new) << member_klass

          has_many association_name, {
            class_name: member_klass.to_s,
            dependent: :nullify,
            foreign_key: 'group_ids',
            extend: MemberAssociationExtensions
          }.merge(options)

          member_klass
        end
      end
    end
  end
end
