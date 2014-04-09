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

      def members
        self.class.default_member_class.any_in(:group_ids => [self.id])
      end

      def member_classes
        self.class.member_classes
      end
      
      def add(*members)
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
          criteria.for_ids(member.group_ids)
        end
        
        def default_member_class
          @default_member_class ||= register(User)
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

          # Define specific members accessor, i.e. group.users
          define_method name.to_s.pluralize.underscore do
            klass.any_in(:group_ids => [self.id])
          end
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
          member_klass
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
        has_and_belongs_to_many :groups, :autosave => true, :inverse_of => nil, :class_name => @group_class_name
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
      
      def in_all_groups?(*groups)
        groups.flatten.to_set.subset? self.groups.to_set
      end

      def in_only_groups?(*groups)
        groups.flatten.to_set == self.groups.to_set
      end
      
      def shares_any_group?(other)
        in_any_group?(other.groups.to_a)
      end
      
      module ClassMethods
        def group_class_name; @group_class_name ||= 'Group'; end
        def group_class_name=(klass);  @group_class_name = klass; end
        
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
        field :named_groups, :type => Array, :default => []
        
        before_save :uniq_named_groups
        protected
        def uniq_named_groups
          named_groups.uniq!
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
