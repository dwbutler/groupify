module Groupify
  module ActiveRecord
    module AssociationExtensions
      extend ActiveSupport::Concern

      # Defined to create alias methods before
      # the association is extended with this module
      def <<(*)
        super
      end

      def add_without_exception(*children)
        add_children_to_parent(children.flatten, false)
      end

      def add_with_exception(*children)
        add_children_to_parent(children.flatten, true)
      end

      alias_method :add_as_usual, :<<
      alias_method :<<, :add_without_exception
      alias_method :add, :add_with_exception

      def as(membership_type)
        return self unless membership_type
        merge(Groupify.group_membership_klass.as(membership_type))
      end

      def delete(*records)
        remove_children_from_parent(records.flatten, :delete){ |*args| super(*args) }
      end

      def destroy(*records)
        remove_children_from_parent(records.flatten, :destroy){ |*args| super(*args) }
      end

    protected

      def remove_children_from_parent(records, destruction_type, &fallback)
        membership_type = records.extract_options![:as]

        if membership_type
          find_for_destruction(membership_type, *records).__send__(:"#{destruction_type}_all")
        else
          fallback.call(*records)
        end

        records.each{|record| record.__send__(:clear_association_cache)}
      end

      def add_children_to_parent(children, exception_on_invalidation)
        membership_type = children.extract_options![:as]

        return self if children.none?

        parent = proxy_association.owner
        parent.__send__(:clear_association_cache)

        to_add_directly = []
        to_add_with_membership_type = []

        # first prepare changes
        children.each do |child|
          # add to collection without membership type
          to_add_directly << child unless self.include?(child)
          # add a second entry for the given membership type
          if membership_type
            membership = find_memberships_for(child, membership_type).first_or_initialize
            to_add_with_membership_type << membership unless membership.persisted?
          end
          parent.__send__(:clear_association_cache)
        end

        # then validate changes
        list_to_validate = to_add_directly + to_add_with_membership_type

        list_to_validate.each do |child|
          next if child.valid?

          if exception_on_invalidation
            raise RecordInvalid.new(child)
          else
            return false
          end
        end

        # then persist changes
        add_as_usual(to_add_directly)

        to_add_with_membership_type.each do |membership|
          membership_parent = membership.__send__(association_parent_type)
          membership_parent.__send__(:"group_memberships_as_#{association_parent_type}") << membership
          membership_parent.__send__(:clear_association_cache)
        end

        self
      end
    end
  end
end
