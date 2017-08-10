module Groupify
  module ActiveRecord
    module CollectionExtensions
      def as(membership_type)
        collection.merge(Groupify.group_membership_klass.as(membership_type))
      end

      def delete(*records)
        remove_children(records, :destroy, records.extract_options![:as])
      end

      def destroy(*records)
        remove_children(records, :destroy, records.extract_options![:as])
      end

      # Defined to create alias methods before
      # the association is extended with this module
      def <<(*children)
        opts = children.extract_options!.merge(exception_on_invalidation: false)
        add_children(children.flatten, opts)
      end

      def add(*children)
        opts = children.extract_options!.merge(exception_on_invalidation: true)
        add_children(children.flatten, opts)
      end

      def collection
        self
      end

      def parent_proxy
        raise "Not implemented"
      end

    protected

      def add_children(children, options = {})
        parent_proxy.add_children(children, options)
      end

      def remove_children(children, destruction_type, membership_type = nil)
        parent_proxy.
          find_memberships_for_children(children, as: membership_type).
          __send__(:"#{destruction_type}_all")

        parent_proxy.clear_association_cache

        children.each{|record| record.__send__(:clear_association_cache)}

        self
      end
    end
  end
end
