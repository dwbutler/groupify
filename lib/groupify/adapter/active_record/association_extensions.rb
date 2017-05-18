module Groupify
  module ActiveRecord
    module AssociationExtensions

      def as(membership_type)
        return self unless membership_type
        where(group_memberships: {membership_type: membership_type})
      end

      def delete(*records)
        opts = records.extract_options!

        if opts[:as]
          find_for_destruction(opts[:as], *records).delete_all
        else
          super(*records)
        end

        records.each{|record| record.__send__(:clear_association_cache)}
      end

      def destroy(*records)
        opts = records.extract_options!

        if opts[:as]
          find_for_destruction(opts[:as], *records).destroy_all
        else
          super(*records)
        end

        records.each{|record| record.__send__(:clear_association_cache)}
      end

    private

      def add_children_to_parent(parent_type, *args)
        opts = {silent: true}.merge args.extract_options!
        membership_type = opts[:as]
        children = args.flatten
        return self unless children.present?

        parent = proxy_association.owner
        parent.__send__(:clear_association_cache)

        finder_method = :"find_memberships_for_#{parent_type == :group ? :member : :group}"

        to_add_directly = []
        to_add_with_membership_type = []

        # first prepare changes
        children.each do |child|
          # add to collection without membership type
          to_add_directly << item unless association.include?(item)
          # add a second entry for the given membership type
          if membership_type
            membership = item.__send__(finder_method, parent, child).first_or_initialize
            to_add_with_membership_type << membership unless membership.persisted?
          end
          parent.__send__(:clear_association_cache)
        end

        # then validate changes
        list_to_validate = to_add_directly + to_add_with_membership_type

        list_to_validate.each do |item|
          next if item.valid?

          if opts[:silent]
            return false
          else
            raise RecordInvalid.new(item)
          end
        end

        # then persist changes
        super(to_add_directly)

        memberships_association = :"group_memberships_as_#{parent_type}"

        to_add_with_membership_type.each do |membership|
          membership_parent = membership.__send__(parent_type)
          membership_parent.__send__(memberships_association) << membership
          membership_parent.__send__(:clear_association_cache)
        end

        self
      end
      alias_method :add, :<<

      def find_memberships_for_member(group, member, membership_type)
        group.group_memberships_as_group.where(member_id: member.id, member_type: member.class.base_class.to_s, membership_type: membership_type)
      end

      def find_memberships_for_group(member, group, membership_type)
        member.group_memberships_as_member.where(group_id: group.id, membership_type: membership_type)
      end

      def find_members_for_destruction(group, member_type)
        group.group_memberships_as_group.
            where(member_id: members.map(&:id), member_type: member_type).
            as(opts[:as])
      end

    end
  end
end
