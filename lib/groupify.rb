require 'active_support'
require 'mongoid'

# Groups and members
module Groupify
  extend ActiveSupport::Concern
  
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
  end

  # Functionality related to groups.
  # Usage:
  #    class Group
  #        acts_as_group, :members => [:users]
  #        ...
  #    end
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
  
  # Functionality related to group members.
  # Usage:
  #    class User
  #        acts_as_group_member
  #        ...
  #    end
  #
  module GroupMember
    extend ActiveSupport::Concern
    
    included do
      group_class_name='Group' unless defined?(@group_class_name)
      field :named_groups, :type => Array
      has_and_belongs_to_many :groups, :autosave => true, :inverse_of => nil, :class_name => @group_class_name do
        def <<(group)
          case group
          when self.metadata.klass
            super
          else
            (self.base.named_groups ||= []) << group.to_s
            self.base.save if self.metadata.autosave
          end
        end
      end
    end
    
    def in_group?(group)
      case group
        when groups.metadata.klass
          self.groups.include?(group)
        else
          self.named_groups ? self.named_groups.include?(group.to_s) : false
        end
    end
    
    def in_any_group?(*groups)
      groups.flatten.each do |group|
        return true if in_group?(group)
      end
      return false
    end
    
    def in_all_groups?(*groups)
      groups.flatten.each do |group|
        return false unless in_group?(group)
      end
      return true
    end
    
    def shares_any_group?(other)
      in_any_group?(other.groups + (other.named_groups || []))
    end
    
    module ClassMethods
      def group_class_name; @group_class_name || 'Group'; end
      def group_class_name=(klass);  @group_class_name = klass; end
      
      def none; where(:id => nil); end
      
      def in_group(group)
        return none unless group.present?
        case group
          when self.reflect_on_association(:groups).klass
            where(:group_ids.in => [group.id])
          else
            in_named_group(group)
        end
      end
      
      def in_named_group(named_group)
        named_group.present? ? where(:named_groups.in => [named_group.to_s]) : none
      end
      
      def in_any_group(*groups)
        groups.present? ? where(:group_ids.in => groups.flatten.map{|g|g.id}) : none
      end
      
      def in_any_named_group(*named_groups)
        named_groups.present? ? where(:named_groups.in => named_groups.flatten.map{|g|g.to_s}) : none
      end
      
      def in_all_groups(*groups)
        groups.present? ? where(:group_ids => groups.flatten.map{|g|g.id}) : none
      end
      
      def in_all_named_groups(*named_groups)
        named_groups.present? ? where(:named_groups => named_groups.flatten.map{|g|g.to_s}) : none
      end
      
      def shares_any_group(other)
        in_any_group(other.groups)
      end
      
      def shares_any_named_group(other)
        in_any_named_group(other.named_groups)
      end
      
    end
  end
end

Mongoid::Document.send :include, Groupify