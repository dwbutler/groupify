module Groupify
  module Mongoid

    module NamedGroupCollection
      # Criteria to filter by membership type
      def as(membership_type)
        return self unless membership_type

        membership = @member.group_memberships.as(membership_type).first
        if membership
          membership.named_groups
        else
          self.class.new
        end
      end

      def <<(named_group, opts={})
        named_group = named_group.to_sym
        super(named_group)
        uniq!

        if @member && opts[:as]
          membership = @member.group_memberships.find_or_initialize_by(as: opts[:as])
          membership.named_groups << named_group
          membership.save!
        end

        self
      end

      def merge(*args)
        opts = args.extract_options!
        named_groups = args.flatten

        named_groups.each do |named_group|
          add(named_group, opts)
        end
      end

      def delete(*args)
        opts = args.extract_options!
        named_groups = args.flatten

        if @member
          if opts[:as]
            membership = @member.group_memberships.as(opts[:as]).first
            if membership
              if ::Mongoid::VERSION > "4"
                membership.pull_all(named_groups: named_groups)
              else
                membership.pull_all(:named_groups, named_groups)
              end
            end

            return
          else
            memberships = @member.group_memberships.where(:named_groups.in => named_groups)
            memberships.each do |membership|
              if ::Mongoid::VERSION > "4"
                membership.pull_all(named_groups: named_groups)
              else
                membership.pull_all(:named_groups, named_groups)
              end
            end
          end
        end

        named_groups.each do |named_group|
          super(named_group)
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
