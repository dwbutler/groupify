module Groupify
  module ActiveRecord
    module GroupAssociationExtensions
      include AssociationExtensions

      def as(membership_type)
        return self unless membership_type
        where(group_memberships: {membership_type: membership_type})
      end

      def <<(*args)
        opts = {silent: true}.merge args.extract_options!
        membership_type = opts[:as]
        groups = args.flatten
        return self unless groups.present?

        member = proxy_association.owner
        member.__send__(:clear_association_cache)

        to_add_directly = []
        to_add_with_membership_type = []

        # first prepare changes
        groups.each do |group|
          # add to collection without membership type
          to_add_directly << group unless include?(group)
          # add a second entry for the given membership type
          if membership_type
            membership = group.group_memberships_as_group.where(member_id: member.id, member_type: member.class.base_class.to_s, membership_type: membership_type).first_or_initialize
            to_add_with_membership_type << membership unless membership.persisted?
          end
          group.__send__(:clear_association_cache)
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

        to_add_with_membership_type.each do |membership|
          membership.group.group_memberships_as_group << membership
          membership.group.__send__(:clear_association_cache)
        end

        self
      end
      alias_method :add, :<<

      def delete(*groups)
        opts = groups.extract_options!

        if opts[:as]
          find_for_destruction(opts[:as], *groups).delete_all
        else
          super(*groups)
        end

        groups.each{|group| group.__send__(:clear_association_cache)}
      end

      def destroy(*groups)
        opts = groups.extract_options!

        if opts[:as]
          find_for_destruction(opts[:as], *groups).destroy_all
        else
          super(*groups)
        end

        groups.each{|group| group.__send__(:clear_association_cache)}
      end

    protected

      def find_for_destruction(membership_type, *groups)
        proxy_association.owner.group_memberships_as_member.where(group_id: groups.map(&:id)).as(membership_type)
      end
    end
  end
end
