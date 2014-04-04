require 'active_record'
require 'set'

# Groups and members
module Groupify
  module ActiveRecord
    module Adapter
      extend ActiveSupport::Concern
      
      included do
        # Define a scope that returns nothing.
        # This is built into ActiveRecord 4, but not 3
        unless self.class.respond_to? :none
          def self.none
            where(arel_table[:id].eq(nil).and(arel_table[:id].not_eq(nil)))
          end
        end
      end
      
      module ClassMethods
        def acts_as_group(opts = {})
          include Groupify::ActiveRecord::Group

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
          include Groupify::ActiveRecord::GroupMember
        end
        
        def acts_as_named_group_member(opts = {})
          include Groupify::ActiveRecord::NamedGroupMember
        end

        def acts_as_group_membership(opts = {})
          include Groupify::ActiveRecord::GroupMembership
        end
      end
    end

    # Usage:
    #    class Group < ActiveRecord::Base
    #        acts_as_group, :members => [:users]
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
        has_many :group_memberships, :dependent => :destroy
      end

      def member_classes
        self.class.member_classes
      end
      
      def add(*members)
        clear_association_cache
        
        members.flatten.each do |member|
          member.groups << self
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

        def associate_member_class(member_klass)
          association_name = member_klass.name.to_s.pluralize.underscore.to_sym
          source_type = member_klass.base_class
          has_many association_name, :through => :group_memberships, :source => :member, :source_type => source_type

          if member_klass == default_member_class
            has_many :members, :through => :group_memberships, :source => :member, :source_type => source_type
          end
        end
      end
    end

    # Join table that tracks which members belong to which groups
    #
    # Usage:
    #    class GroupMembership < ActiveRecord::Base
    #        acts_as_group_membership
    #        ...
    #    end
    #
    module GroupMembership
      extend ActiveSupport::Concern

      included do
        belongs_to :member, :polymorphic => true
        belongs_to :group
      end

      module ClassMethods
        def named(group_name=nil, type=nil)
          if group_name.present?
            if type.present?
              where(group_name: group_name, type: type)
            else
              where(group_name: group_name)
            end    
          else
            where("group_name IS NOT NULL")
          end
        end
      end
    end

    # Usage:
    #    class User < ActiveRecord::Base
    #        acts_as_group_member
    #        ...
    #    end
    #
    #    user.groups << group
    #
    module GroupMember
      extend ActiveSupport::Concern
      
      included do
        has_many :group_memberships, :as => :member, :autosave => true, :dependent => :destroy
        has_many :groups, :through => :group_memberships, :class_name => @group_class_name
      end
      
      def in_group?(group)
        self.group_memberships.exists?(:group_id => group.id)
      end
      
      def in_any_group?(*groups)
        groups.flatten.each do |group|
          return true if in_group?(group)
        end
        return false
      end
      
      def in_all_groups?(*groups)
        Set.new(groups.flatten) == Set.new(self.named_groups)
      end
      
      def shares_any_group?(other)
        in_any_group?(other.groups)
      end
      
      module ClassMethods
        def group_class_name; @group_class_name ||= 'Group'; end
        def group_class_name=(klass);  @group_class_name = klass; end
        
        def in_group(group)
          group.present? ? joins(:group_memberships).where(:group_memberships => {:group_id => group.id}).uniq : none
        end
        
        def in_any_group(*groups)
          groups.present? ? joins(:group_memberships).where(:group_memberships => {:group_id => groups.flatten.map(&:id)}).uniq : none
        end
        
        def in_all_groups(*groups)
          if groups.present?
            groups = groups.flatten

            joins(:group_memberships).
            group(:"group_memberships.member_id").
            where(:group_memberships => {:group_id => groups.map(&:id)}).
            having("COUNT(group_memberships.group_id) = #{groups.count}").
            uniq
          else
            none
          end
        end
        
        def shares_any_group(other)
          in_any_group(other.groups)
        end
        
      end
    end

    class NamedGroupCollection < Set
      def initialize(member, type=nil)
        @member = member
        super(member.group_memberships.named(type).pluck(:group_name).map(&:to_sym))
      end

      def <<(opts)
        if opts.is_a? Hash
          named_group = opts[:named_group]
          type = opts[:type]
        else
          named_group = opts
          type = nil
        end    
        
        named_group = named_group.to_sym
        type = type.to_sym unless type.nil?

        unless include?(named_group)
          @member.group_memberships.build(:group_name => named_group, :type => type)
          super(named_group)
        end
        named_group
      end
    end

    
    # Usage:
    #    class User < ActiveRecord::Base
    #        acts_as_named_group_member
    #        ...
    #    end
    #
    #    user.named_groups << :admin
    #
    module NamedGroupMember
      extend ActiveSupport::Concern

      def named_groups(type=nil)
        @named_groups ||= NamedGroupCollection.new(self, type)
      end

      def named_groups=(named_groups, type=nil)
        named_groups.each do |named_group|
          self.named_groups << named_group
        end
      end
      
      def in_named_group?(group, type=nil)
        named_groups(type).include?(group)
      end
      
      def in_any_named_group?(*groups)
        groups.flatten.each do |group|
          return true if in_named_group?(group)
        end
        return false
      end
      
      def in_all_named_groups?(*groups)
        Set.new(groups.flatten) == Set.new(self.named_groups)
      end
      
      def shares_any_named_group?(other)
        in_any_named_group?(other.named_groups.to_a)
      end
      
      module ClassMethods
        def in_named_group(named_group)
          named_group.present? ? joins(:group_memberships).where(:group_memberships => {:group_name => named_group}).uniq  : none
        end
        
        def in_any_named_group(*named_groups)
          named_groups.present? ? joins(:group_memberships).where(:group_memberships => {:group_name => named_groups.flatten}).uniq : none
        end
        
        def in_all_named_groups(*named_groups)
          if named_groups.present?
            named_groups = named_groups.flatten.map(&:to_s)

            joins(:group_memberships).
            group(:"group_memberships.member_id").
            where(:group_memberships => {:group_name => named_groups}).
            having("COUNT(group_memberships.group_name) = #{named_groups.count}").
            uniq
          else
            none
          end
        end
        
        def shares_any_named_group(other)
          in_any_named_group(other.named_groups.to_a)
        end
      end
    end
  end
end

ActiveRecord::Base.send :include, Groupify::ActiveRecord::Adapter
