require 'groupify/adapter/active_record/collection_extensions'

module Groupify
  module ActiveRecord
    module AssociationExtensions
      include CollectionExtensions

      def owner
        proxy_association.owner
      end

      def source_name
        ActiveRecord.check_group_memberships_for_association!(self) == :group_memberships_as_group ? :member : :group
      end

    protected

      # Throw an exception here when adding direction to an association
      # because when adding the children to the parent this won't
      # happen because the group membership is polymorphic.
      def add_children(children, opts = {})
        children.each do |child|
          proxy_association.__send__(:raise_on_type_mismatch!, child)
        end

        super
      end
    end
  end
end
