module Groupify
  module ActiveRecord

    class NamedGroupCollection < Set
      def initialize(member)
        @member = member
        @named_group_memberships = member.group_memberships.named
        @group_names = @named_group_memberships.pluck(:group_name).map(&:to_sym)
        super(@group_names)
      end

      def add(named_group, opts={})
        named_group = named_group.to_sym
        membership_type = opts[:as]

        if @member.new_record?
          @member.group_memberships.build(group_name: named_group, membership_type: nil)
        else
          @member.transaction do
            @member.group_memberships.where(group_name: named_group, membership_type: nil).first_or_create!
          end
        end

        if membership_type
          if @member.new_record?
            @member.group_memberships.build(group_name: named_group, membership_type: membership_type)
          else
            @member.group_memberships.where(group_name: named_group, membership_type: membership_type).first_or_create!
          end
        end

        super(named_group)
      end

      alias_method :push, :add
      alias_method :<<, :add

      def merge(*args)
        opts = args.extract_options!
        named_groups = args.flatten
        named_groups.each do |named_group|
          add(named_group, opts)
        end
      end

      alias_method :concat, :merge

      def include?(named_group, opts={})
        named_group = named_group.to_sym
        if opts[:as]
          as(opts[:as]).include?(named_group)
        else
          super(named_group)
        end
      end

      def delete(*args)
        opts = args.extract_options!
        named_groups = args.flatten.compact

        remove(named_groups, :delete_all, opts)
      end

      def destroy(*args)
        opts = args.extract_options!
        named_groups = args.flatten.compact

        remove(named_groups, :destroy_all, opts)
      end

      def clear
        @named_group_memberships.delete_all
        super
      end

      alias_method :delete_all, :clear
      alias_method :destroy_all, :clear

      # Criteria to filter by membership type
      def as(membership_type)
        @named_group_memberships.as(membership_type).pluck(:group_name).map(&:to_sym)
      end

      protected

      def remove(named_groups, method, opts)
        if named_groups.present?
          scope = @named_group_memberships.where(group_name: named_groups)

          if opts[:as]
            scope = scope.where(membership_type: opts[:as])
          end

          scope.send(method)

          unless opts[:as]
            named_groups.each do |named_group|
              @hash.delete(named_group)
            end
          end
        end
      end
    end
  end
end
