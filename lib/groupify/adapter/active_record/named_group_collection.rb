module Groupify
  module ActiveRecord

    class NamedGroupCollection < Set
      def initialize(member)
        @member = member
        @named_group_memberships = member.group_memberships_as_member.named
        @group_names = @named_group_memberships.pluck(:group_name).map(&:to_sym)

        super(@group_names)
      end

      def add(named_group, opts = {})
        named_group = named_group.to_sym
        membership_type = opts[:as]
        membership_type = membership_type.to_s if membership_type.is_a?(Symbol)
        # always add a nil membership type and then a specific one (if specified)
        membership_types = [nil, membership_type].uniq

        @member.transaction do
          membership_types.each do |membership_type|
            if @member.new_record?
              @member.group_memberships_as_member.build(group_name: named_group, membership_type: membership_type)
            else
              @member.group_memberships_as_member.where(group_name: named_group, membership_type: membership_type).first_or_create!
            end
          end
        end

        super(named_group)
      end

      alias_method :push, :add
      alias_method :<<, :add

      def merge(*named_groups)
        opts = named_groups.extract_options!

        named_groups.flatten.each do |named_group|
          add(named_group, opts)
        end
      end

      alias_method :concat, :merge

      def include?(named_group, opts = {})
        named_group = named_group.to_sym

        if opts[:as]
          as(opts[:as]).include?(named_group)
        else
          super(named_group)
        end
      end

      def delete(*named_groups)
        opts = named_groups.extract_options!

        remove(named_groups.flatten.compact, :delete_all, opts[:as])
      end

      def destroy(*named_groups)
        opts = named_groups.extract_options!

        remove(named_groups.flatten.compact, :destroy_all, opts[:as])
      end

      def clear
        @named_group_memberships.delete_all
        super
      end

      alias_method :delete_all, :clear
      alias_method :destroy_all, :clear

      # Criteria to filter by membership type
      def as(membership_type)
        if membership_type.present?
          @named_group_memberships.as(membership_type).pluck(:group_name).map(&:to_sym)
        else
          to_a
        end
      end

    protected

      def remove(named_groups, destruction_type, membership_type = nil)
        if named_groups.present?
          @named_group_memberships.
            where(group_name: named_groups).
            as(membership_type).
            __send__(destruction_type)

          unless membership_type.present?
            named_groups.each do |named_group|
              @hash.delete(named_group)
            end
          end
        end
      end
    end
  end
end
