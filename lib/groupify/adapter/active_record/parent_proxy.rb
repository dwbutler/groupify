module Groupify
  module ActiveRecord
    class ParentProxy

      attr_reader :parent_type, :child_type

      def initialize(parent, parent_type)
        @parent, @parent_type = parent, parent_type
        @child_type = parent_type == :group ? :member : :group
      end

      def find_memberships_for_children(children, options = {})
        memberships_association.__send__(:"for_#{@child_type}s", children).as(options[:as])
      end

      def add_children(children, options = {})
        return @parent if children.none?

        clear_association_cache

        membership_type = options[:as]

        to_add_directly = []
        to_add_with_membership_type = []

        already_children = find_memberships_for_children(children).includes(@child_type).group_by{ |membership| membership.__send__(@child_type) }

        # first prepare changes
        children.each do |child|
          # add to collection without membership type
          unless already_children[child] && already_children[child].find{ |m| m.membership_type.nil? }
            to_add_directly << memberships_association.build(@child_type => child)
          end

          # add a second entry for the given membership type
          if membership_type.present?
            membership =  memberships_association.
                            merge(memberships_association_for(child, @child_type)).
                            as(membership_type).
                            first_or_initialize
            to_add_with_membership_type << membership unless membership.persisted?
          end

          clear_association_cache_for(child)
        end

        clear_association_cache

        # then validate changes
        list_to_validate = to_add_directly + to_add_with_membership_type

        list_to_validate.each do |child|
          next if child.valid?

          if options[:exception_on_invalidation]
            raise ::ActiveRecord::RecordInvalid.new(child)
          else
            return false
          end
        end

        # create memberships without membership type
        memberships_association << to_add_directly

        # create memberships with membership type
        to_add_with_membership_type.
          group_by{ |membership| membership.__send__(@parent_type) }.
          each do |membership_parent, memberships|
            memberships_association_for(membership_parent, @parent_type) << memberships
            clear_association_cache_for(membership_parent)
          end

        @parent
      end

      def children_association
        @parent.__send__(Groupify.__send__(:"#{@child_type}s_association_name"))
      end

      def memberships_association
        memberships_association_for(@parent, @parent_type)
      end

      def clear_association_cache
        clear_association_cache_for(@parent)
      end

    private

      def memberships_association_for(record, source)
        record.__send__(:"group_memberships_as_#{source}")
      end

      def clear_association_cache_for(record)
        record.__send__(:clear_association_cache)
      end
    end
  end
end
