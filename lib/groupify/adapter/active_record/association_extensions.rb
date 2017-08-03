module Groupify
  module ActiveRecord
    module AssociationExtensions
      extend ActiveSupport::Concern

      def as(membership_type)
        merge(Groupify.group_membership_klass.as(membership_type))
      end

      def delete(*records)
        remove_children(records, :destroy, records.extract_options![:as])
      end

      def destroy(*records)
        remove_children(records, :destroy, records.extract_options![:as])
      end

      # Defined to create alias methods before
      # the association is extended with this module
      def <<(*)
        super
      end

      def add_without_exception(*children)
        add_children(children, children.extract_options!.merge(exception_on_invalidation: false))
      end

      def add_with_exception(*children)
        add_children(children, children.extract_options!.merge(exception_on_invalidation: true))
      end

      alias_method :add_as_usual, :<<
      alias_method :<<, :add_without_exception
      alias_method :add, :add_with_exception

    protected

      def add_children(children, options = {})
        # Throw an exception here when adding direction to an association
        # because when adding the children to the parent this won't
        # happen because the group membership is polymorphic.
        children.each do |child|
          proxy_association.__send__(:raise_on_type_mismatch!, child)
        end

        ActiveRecord.add_children_to_parent(
          proxy_association,
          children,
          options
        )
      end

      def remove_children(children, destruction_type, membership_type = nil)
        ActiveRecord.find_memberships_for(
          proxy_association,
          children,
          as: membership_type
        ).__send__(:"#{destruction_type}_all")

        children.each{|record| record.__send__(:clear_association_cache)}

        self
      end
    end
  end
end
