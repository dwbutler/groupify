module Groupify
  module ActiveRecord
    module CollectionExtensions
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

      def owner
        raise "Not implemented"
      end

      def source_name
        raise "Not implemented"
      end

    protected

      def add_children(children, opts = {})
        owner.__send__(:"add_#{source_name}s", children, opts)
      end

      def remove_children(children, destruction_type, membership_type = nil)
        owner.
          __send__(:"find_memberships_for_#{source_name}s", children).
          as(membership_type).
          __send__(:"#{destruction_type}_all")

        owner.__send__(:clear_association_cache)

        children.each{|record| record.__send__(:clear_association_cache)}

        self
      end
    end
  end
end
