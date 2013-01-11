require 'active_support'
require 'mongoid'
require 'set'

# Groups and members
module Groupify
  extend ActiveSupport::Concern
  
  included do
    def none; where(:id => nil); end
  end
  
  module ClassMethods
    def acts_as_group(opts = {})
      include Groupify::Group
      
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
      class_eval { @group_class_name = opts[:class_name] || 'Group' }
      include Groupify::GroupMember
    end
    
    def acts_as_named_group_member(opts = {})
      include Groupify::NamedGroupMember
    end
  end

  # Usage:
  #    class Group
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
    end
    
    def members
      self.class.default_member_class.any_in(:group_ids => [self.id])
    end
    
    def add(member)
      member.groups << self
    end
    
    module ClassMethods
      def with_member(member)
        criteria.for_ids(member.group_ids)
      end
      
      def default_member_class; @default_member_class || User; end
      def default_member_class=(klass); @default_member_class = klass; end
      
      # Define which classes are members of this group
      def has_members(name)
        klass = name.to_s.classify.constantize
        define_method name.to_s.pluralize.underscore do
          klass.any_in(:group_ids => [self.id])
        end
      end
    end
  end
  
  # Usage:
  #    class User
  #        acts_as_group_member
  #        ...
  #    end
  #
  #    user.groups << group
  #
  module GroupMember
    extend ActiveSupport::Concern
    
    included do
      group_class_name='Group' unless defined?(@group_class_name)
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
      Set.new(groups.flatten) == Set.new(self.named_groups)
    end
    
    def shares_any_group?(other)
      in_any_group?(other.groups)
    end
    
    module ClassMethods
      def group_class_name; @group_class_name || 'Group'; end
      def group_class_name=(klass);  @group_class_name = klass; end
      
      def in_group(group)
        group.present? ? where(:group_ids.in => [group.id]) : none
      end
      
      def in_any_group(*groups)
        groups.present? ? where(:group_ids.in => groups.flatten.map{|g|g.id}) : none
      end
      
      def in_all_groups(*groups)
        groups.present? ? where(:group_ids => groups.flatten.map{|g|g.id}) : none
      end
      
      def shares_any_group(other)
        in_any_group(other.groups)
      end
      
    end
  end
  
  # Usage:
  #    class User
  #        acts_as_named_group_member
  #        ...
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
      self.named_groups.include?(group)
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
      in_any_named_group?(other.named_groups)
    end
    
    module ClassMethods
      def in_named_group(named_group)
        named_group.present? ? where(:named_groups.in => [named_group]) : none
      end
      
      def in_any_named_group(*named_groups)
        named_groups.present? ? where(:named_groups.in => named_groups.flatten) : none
      end
      
      def in_all_named_groups(*named_groups)
        named_groups.present? ? where(:named_groups => named_groups.flatten) : none
      end
      
      def shares_any_named_group(other)
        in_any_named_group(other.named_groups)
      end
    end
  end
end

Mongoid::Document.send :include, Groupify