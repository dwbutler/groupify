module Groupify
  module ActiveRecord
    module MemberAssociationExtensions
      include AssociationExtensions
      
      def as(membership_type)
        where(group_memberships: {membership_type: membership_type})
      end

      def <<(*args)
        opts = {silent: true}.merge args.extract_options!
        membership_type = opts[:as]
        members = args.flatten
        return self unless members.present?

        group = proxy_association.owner
        group.__send__(:clear_association_cache)

        to_add_directly = []
        to_add_with_membership_type = []

        # first prepare changes
        members.each do |member|
          # add to collection without membership type
          to_add_directly << member unless include?(member)
          # add a second entry for the given membership type
          if membership_type
            membership = member.group_memberships_as_member.where(group_id: group.id, membership_type: membership_type).first_or_initialize
            to_add_with_membership_type << membership unless membership.persisted?
          end
          member.__send__(:clear_association_cache)
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
          membership.member.group_memberships_as_member << membership
          membership.member.__send__(:clear_association_cache)
        end

        self
      end
      alias_method :add, :<<

      def delete(*members)
        opts = members.extract_options!

        if opts[:as]
          find_for_destruction(opts[:as], *members).delete_all
        else
          super(*members)
        end

        members.each{|member| member.__send__(:clear_association_cache)}
      end

      def destroy(*members)
        opts = members.extract_options!

        if opts[:as]
          find_for_destruction(opts[:as], *members).destroy_all
        else
          super(*members)
        end

        members.each{|member| member.__send__(:clear_association_cache)}
      end

    protected

      def find_for_destruction(membership_type, *members)
        proxy_association.owner.group_memberships_as_group.
          where(member_id: members.map(&:id), member_type: proxy_association.reflection.options[:source_type]).
          as(membership_type)
      end
    end
  end
end
