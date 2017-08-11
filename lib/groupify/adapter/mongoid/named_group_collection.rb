module Groupify
  module Mongoid

    module NamedGroupCollection
      # Criteria to filter by membership type
      def as(membership_type)
        return self unless membership_type.present?

        membership = @member.group_memberships.as(membership_type).first

        membership ? membership.named_groups : self.class.new
      end

      def <<(named_group, opts = {})
        named_group = named_group.to_sym
        super(named_group)
        uniq!

        if @member && opts[:as].present?
          membership = @member.group_memberships.find_or_initialize_by(as: opts[:as])
          membership.named_groups << named_group
          membership.save!
        end

        self
      end

      def merge(*named_groups)
        opts = named_groups.extract_options!

        named_groups.flatten.each do |named_group|
          add(named_group, opts)
        end
      end

      def delete(*named_groups)
        membership_type = named_groups.extract_options![:as]
        named_groups.flatten!

        if @member
          if membership_type.present?
            skip_default = true
            memberships = [@member.group_memberships.as(membership_type).first]
          else
            memberships = @member.group_memberships.where(:named_groups.in => named_groups)
          end

          memberships.each do |membership|
            if ::Mongoid::VERSION > "4"
              membership.pull_all(named_groups: named_groups)
            else
              membership.pull_all(:named_groups, named_groups)
            end
          end
        end

        unless skip_default
          named_groups.each do |named_group|
            super(named_group)
          end
        end
      end

      def self.extended(base)
        base.class_eval do
          attr_accessor :member

          alias_method :delete_all, :clear
          alias_method :destroy_all, :clear
          alias_method :push, :<<
          alias_method :add, :<<
          alias_method :concat, :merge
          alias_method :destroy, :delete
        end
      end
    end
  end
end
