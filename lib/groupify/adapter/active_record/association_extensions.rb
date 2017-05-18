module Groupify
  module ActiveRecord
    module AssociationExtensions
      extend ActiveSupport::Concern

      module ClassMethods
        def setup_alias_methods!
          alias_method :add_as_usual, :<<
          alias_method :<<, :add_without_exception
          alias_method :add, :add_with_exception
        end
      end

      def add_without_exception(*children)
        add_children_to_parent(children.flatten, false)
      end

      def add_with_exception(*children)
        add_children_to_parent(children.flatten, true)
      end

      def as(membership_type)
        return self unless membership_type
        where(group_memberships: {membership_type: membership_type})
      end

      def delete(*records)
        remove_children_from_parent(:delete, *records, &super)
      end

      def destroy(*records)
        remove_children_from_parent(:destroy, *records, &super)
      end

    protected

      def remove_children_from_parent(destruction_type, *records)
        membership_type = records.extract_options![:as]

        if membership_type
          find_for_destruction(membership_type, *records).__send__(:"#{destruction_type}_all")
        else
          super(*records)
        end

        records.each{|record| record.__send__(:clear_association_cache)}
      end

      def add_children_to_parent(parent_type, should_raise_exception, *args, &_super)
        children = args.flatten
        return self unless children.present?

        parent = proxy_association.owner
        parent.__send__(:clear_association_cache)

        to_add_directly = []
        to_add_with_membership_type = []

        # first prepare changes
        children.each do |child|
          # add to collection without membership type
          to_add_directly << item unless association.include?(item)
          # add a second entry for the given membership type
          if membership_type
            membership = find_memberships_for_adding_children(parent, child).first_or_initialize
            to_add_with_membership_type << membership unless membership.persisted?
          end
          parent.__send__(:clear_association_cache)
        end

        # then validate changes
        list_to_validate = to_add_directly + to_add_with_membership_type

        list_to_validate.each do |item|
          next if item.valid?

          if should_raise_exception
            raise RecordInvalid.new(item)
          else
            return false
          end
        end

        # then persist changes
        _super.call(to_add_directly)

        memberships_association = :"group_memberships_as_#{parent_type}"

        to_add_with_membership_type.each do |membership|
          membership_parent = membership.__send__(parent_type)
          membership_parent.__send__(memberships_association) << membership
          membership_parent.__send__(:clear_association_cache)
        end

        self
      end
    end
  end
end
