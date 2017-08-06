require 'groupify/adapter/active_record/collection_extensions'

module Groupify
  module ActiveRecord
    module AssociationExtensions
      include CollectionExtensions

      def collection
        self
      end

      def collection_parent
        proxy_association.owner
      end

      def collection_parent_type
        ActiveRecord.infer_parent_and_types(proxy_association)[1]
      end

    protected

      def add_children(children, options = {})
        # Throw an exception here when adding direction to an association
        # because when adding the children to the parent this won't
        # happen because the group membership is polymorphic.
        children.each do |child|
          proxy_association.__send__(:raise_on_type_mismatch!, child)
        end

        super
      end
    end
  end
end
