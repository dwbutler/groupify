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

    protected

      def add_children(children, options = {})
        ActiveRecord.add_children_to_parent(
          collection_parent,
          children,
          options.merge(parent_type: collection_parent_type)
        )
      end

      def remove_children(children, destruction_type, membership_type = nil)
        ActiveRecord.find_memberships_for(
          collection_parent,
          children,
          parent_type: collection_parent_type,
          as: membership_type
        ).__send__(:"#{destruction_type}_all")

        collection_parent.__send__(:clear_association_cache)

        children.each{|record| record.__send__(:clear_association_cache)}

        self
      end
    end
  end
end
