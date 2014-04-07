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
      
      def add(*args)
        opts = args.last.is_a?(Hash) ? args.pop : {}
        membership_type = opts[:as]
        members = args
        return unless members.present?

        clear_association_cache
        
        members.flatten.each do |member|
          member.group_memberships.create!(group: self, membership_type: membership_type)
        end
      end

      # Merge a source group into this group.
      def merge!(source)
        self.class.merge!(source, self)
      end
      
      module ClassMethods
        def with_member(member, opts={})
          #joins(:group_memberships).where(:group_memberships => {:member_id => member.id, :member_type => member.class.to_s})
          member.groups(opts)
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
          override_member_accessor(association_name)

          if member_klass == default_member_class
            has_many :members, :through => :group_memberships, :source => :member, :source_type => source_type
            override_member_accessor(:members)
          end
        end

        def override_member_accessor(association_name)
          define_method(association_name) do |*args|
            opts = args.last.is_a?(Hash) ? args.pop : {}
            membership_type = opts[:as]
            if membership_type.present?
              super().joins(:group_memberships).where("group_memberships.membership_type" => membership_type)
            else
              super()
            end
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
        attr_accessible(:member, :group, :group_name, :membership_type, :as) if ActiveSupport::VERSION::MAJOR < 4

        belongs_to :member, :polymorphic => true
        belongs_to :group
      end

      def membership_type=(membership_type)
        self[:membership_type] = membership_type.to_s if membership_type.present?
      end

      def as=(membership_type)
        self.membership_type = membership_type
      end

      def as
        membership_type
      end

      module ClassMethods
        def named(group_name=nil)
          if group_name.present?
            where(group_name: group_name)
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

      def groups(*args)
        opts = args.last.is_a?(Hash) ? args.pop : {}
        groups = super
        if opts[:as]
          groups.joins(:group_memberships).where("group_memberships.membership_type" => opts[:as])
        else
          groups
        end
      end
      
      def in_group?(group, opts={})
        criteria = {:group_id => group.id}
        if opts[:as]
          criteria.merge!(membership_type: opts[:as])
        end

        group_memberships.exists?(criteria)
      end
      
      def in_any_group?(*args)
        opts = (args.last.is_a?(Hash) ? args.pop : {})
        groups = args

        groups.flatten.each do |group|
          return true if in_group?(group, opts)
        end
        return false
      end
      
      def in_all_groups?(*groups)
        Set.new(groups.flatten) == Set.new(self.named_groups)
      end
      
      def shares_any_group?(other, opts={})
        in_any_group?(other.groups, opts)
      end
      
      module ClassMethods
        def group_class_name; @group_class_name ||= 'Group'; end
        def group_class_name=(klass);  @group_class_name = klass; end
        
        def in_group(group, opts={})
          return none unless group.present?

          scope = joins(:group_memberships).where(:group_memberships => {:group_id => group.id}).uniq
          if opts[:as]
            scope.where(:group_memberships => {:membership_type => opts[:as]})
          end
          scope
        end
        
        def in_any_group(*args)
          opts = (args.last.is_a?(Hash) ? args.pop : {})
          groups = args
          return none unless groups.present?
          
          scope = joins(:group_memberships).where(:group_memberships => {:group_id => groups.flatten.map(&:id)}).uniq
          if opts[:as]
            scope.where(:group_memberships => {:membership_type => opts[:as]})
          end
          scope
        end
        
        def in_all_groups(*args)
          opts = (args.last.is_a?(Hash) ? args.pop : {})
          groups = args

          if groups.present?
            groups = groups.flatten

            scope = joins(:group_memberships).
            group(:"group_memberships.member_id").
            where(:group_memberships => {:group_id => groups.map(&:id)}).
            having("COUNT(group_memberships.group_id) = #{groups.count}").
            uniq

            if opts[:as]
              scope.where(:group_memberships => {:membership_type => opts[:as]})
            end

            scope
          else
            none
          end
        end
        
        def shares_any_group(other, opts={})
          in_any_group(other.groups, opts)
        end
        
      end
    end

    class NamedGroupCollection < Set
      def initialize(member)
        @member = member
        group_names = member.group_memberships.named.pluck(:group_name).map(&:to_sym)
        super(group_names)
      end

      def <<(named_group, opts={})
        named_group = named_group.to_sym
        unless include?(named_group)
          attributes = opts.merge(:group_name => named_group)
          if @member.new_record?
            @member.group_memberships.build(attributes)
          else
            @member.group_memberships.create!(attributes)
          end
          super(named_group)
        end
        named_group
      end

      def concat(*named_groups)
        named_groups.flatten.each do |named_group|
          self << named_group
        end
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

      def named_groups
        @named_groups ||= NamedGroupCollection.new(self)
      end

      def named_groups=(named_groups)
        named_groups.each do |named_group|
          self.named_groups << named_group
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
