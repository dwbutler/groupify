require 'mongoid'
require 'set'

# Groups and members
module Groupify
  module Mongoid
    module Adapter
      extend ActiveSupport::Concern
      
      included do
        def none; where(:id => nil); end
      end
      
      module ClassMethods
        def acts_as_group(opts = {})
          include Groupify::Mongoid::Group
          
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
          include Groupify::Mongoid::GroupMember
        end
        
        def acts_as_named_group_member(opts = {})
          include Groupify::Mongoid::NamedGroupMember
        end
      end
    end

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
          membership = member.group_memberships.find_or_initialize_by(membership_type: membership_type)
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
            if klass.any_in(:group_ids => [source_group.id]).count > 0
              raise ArgumentError.new("#{source_group.class} has members that cannot belong to #{destination_group.class}")
            end
          end

          source_group.member_classes.each do |klass|
            klass.any_in(:group_ids => [source_group.id]).update_all(:$set => {:"group_ids.$" => destination_group.id})
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
    
    # Usage:
    #    class User
    #      include Mongoid::Document
    #
    #      acts_as_group_member
    #      ...
    #    end
    #
    #    user.groups << group
    #
    module GroupMember
      extend ActiveSupport::Concern
      
      included do
        has_and_belongs_to_many :groups, autosave: true, dependent: :nullify, inverse_of: nil, class_name: @group_class_name do
          def as(membership_type)
            return self unless membership_type
            group_ids = base.group_memberships.as(membership_type).first.group_ids

            if group_ids.present?
              self.and(:id.in => group_ids)
            else
              self.and(:id => nil)
            end
          end

          def destroy(*args)
            delete(*args)
          end

          def delete(*args)
            opts = args.extract_options!
            groups = args.flatten


            if opts[:as]
              base.group_memberships.as(opts[:as]).each do |membership|
                membership.groups.delete(*groups)
              end
            else
              super(*groups)
            end
          end
        end

        class GroupMembership
          include ::Mongoid::Document

          embedded_in :member, polymorphic: true

          field :named_groups, type: Array, default: -> { [] }

          after_initialize do
            named_groups.extend NamedGroupCollection
          end

          field :as, as: :membership_type, type: String

          def group=(group)
            groups << group
          end

          def group_name=(group_name)
            group_names << group_name
          end
        end

        GroupMembership.send :has_and_belongs_to_many, :groups, class_name: @group_class_name, inverse_of: nil

        embeds_many :group_memberships, class_name: GroupMembership.to_s, as: :member do
          def as(membership_type)
            where(membership_type: membership_type.to_s)
          end
        end
      end
      
      def in_group?(group)
        self.groups.include?(group)
      end
      
      def in_any_group?(*groups)
        groups.flatten.each do |group|
          return true if in_group?(group)
        end
        return false
      end

      def in_all_groups?(*args)
        opts = args.extract_options!
        groups = args

        groups.flatten.to_set.subset? self.groups.as(opts[:as]).to_set
      end

      def in_only_groups?(*args)
        opts = args.extract_options!
        groups = args.flatten

        groups.to_set == self.groups.as(opts[:as]).to_set
      end

      def shares_any_group?(other, opts={})
        in_any_group?(other.groups, opts)
      end
      
      module ClassMethods
        def group_class_name; @group_class_name ||= 'Group'; end
        def group_class_name=(klass);  @group_class_name = klass; end

        def as(membership_type)
          # If filtering by groups, merge into the group membership criteria
          if criteria.selector.key? "group_ids"
            where(:group_memberships.elem_match => { as: membership_type, group_ids: criteria.selector["group_ids"] }).tap do |criteria|
              criteria.selector.delete("group_ids")
            end
          else
          # case group_ids_selector
          # when Hash
          #   if group_ids_selector["$in"]
          #     where(:group_memberships.elem_match => { as: membership_type, :group_ids.in => group_ids_selector["$in"] })
          #   elsif group_ids_selector["$all"]
          #     where(:group_memberships.elem_match => { as: membership_type, group_ids: group_ids_selector["$all"] })
          #   end
          # when Array
          #   where(:group_memberships.elem_match => { as: membership_type, group_ids: group_ids_selector })
          # else
            #where(:group_memberships.elem_match => { as: membership_type })
            where(:"group_memberships.as" => membership_type)
          end
        end
        
        def in_group(group)
          group.present? ? self.in(group_ids: group.id) : none
        end
        
        def in_any_group(*groups)
          groups.present? ? self.in(group_ids: groups.flatten.map(&:id)) : none
        end

        def in_all_groups(*groups)
          groups.present? ? where(:group_ids.all => groups.flatten.map(&:id)) : none
        end
        
        def in_only_groups(*groups)
          groups.present? ? where(:group_ids => groups.flatten.map(&:id)) : none
        end
        
        def shares_any_group(other)
          in_any_group(other.groups.to_a)
        end
        
      end
    end

    module NamedGroupCollection
      def <<(named_group)
        named_group = named_group.to_sym
        super(named_group)
        uniq!
        self
      end

      def merge(*named_groups)
        named_groups.flatten.each do |named_group|
          add(named_group)
        end
      end

      def delete(*named_groups)
        named_groups.flatten.each do |named_group|
          super(named_group)
        end
      end

      def self.extended(base)
        base.class_eval do
          alias_method :delete_all, :clear
          alias_method :destroy_all, :clear
          alias_method :push, :<<
          alias_method :add, :<<
          alias_method :concat, :merge
          alias_method :destroy, :delete
        end
      end
    end
    
    # Usage:
    #    class User
    #      include Mongoid::Document
    #
    #      acts_as_named_group_member
    #      ...
    #    end
    #
    #    user.named_groups << :admin
    #
    module NamedGroupMember
      extend ActiveSupport::Concern
      
      included do
        field :named_groups, type: Array, default: -> { [] }

        after_initialize do
          named_groups.extend NamedGroupCollection
        end
      end
      
      def in_named_group?(group)
        named_groups.include?(group)
      end
      
      def in_any_named_group?(*groups)
        groups.flatten.each do |group|
          return true if in_named_group?(group)
        end
        return false
      end
      
      def in_all_named_groups?(*groups)
        groups.flatten.to_set.subset? self.named_groups.to_set
      end

      def in_only_named_groups?(*groups)
        groups.flatten.to_set == self.named_groups.to_set
      end
      
      def shares_any_named_group?(other)
        in_any_named_group?(other.named_groups)
      end
      
      module ClassMethods
        def in_named_group(named_group)
          named_group.present? ? self.in(named_groups: named_group) : none
        end
        
        def in_any_named_group(*named_groups)
          named_groups.present? ? self.in(named_groups: named_groups.flatten) : none
        end

        def in_all_named_groups(*named_groups)
          named_groups.present? ? where(:named_groups.all => named_groups.flatten) : none
        end
        
        def in_only_named_groups(*named_groups)
          named_groups.present? ? where(:named_groups => named_groups.flatten) : none
        end
        
        def shares_any_named_group(other)
          in_any_named_group(other.named_groups)
        end
      end
    end
  end
end

Mongoid::Document.send :include, Groupify::Mongoid::Adapter
