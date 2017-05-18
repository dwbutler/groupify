module Groupify
  module ActiveRecord
    module GroupAssociationExtensions
      include AssociationExtensions

      def <<(*children)
        add_children_to_parent(:group, *children)
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
