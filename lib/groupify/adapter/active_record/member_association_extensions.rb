module Groupify
  module ActiveRecord
    module MemberAssociationExtensions
      include AssociationExtensions

      def <<(*children)
        add_children_to_parent(:member, *children)
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
