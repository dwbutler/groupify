module Groupify
  module ActiveRecord
    class ParentProxy

      attr_reader :parent_type, :child_type

      def initialize(parent, parent_type)
        @parent, @parent_type = parent, parent_type
        @child_type = parent_type == :group ? :member : :group
      end

      def find_memberships_for(children, options = {})
        memberships_association.__send__(:"for_#{@child_type}s", children).as(options[:as])
      end

      def add_children(children, options = {})
        return @parent if children.none?

        clear_association_cache

        membership_type = options[:as]
        exception_on_invalidation = options[:exception_on_invalidation]

        to_add_directly = []
        to_add_with_membership_type = []

        already_children = find_memberships_for(children).includes(@child_type).group_by{ |membership| membership.__send__(@child_type) }

        # first prepare changes
        children.each do |child|
          # add to collection without membership type
          unless already_children[child] && already_children[child].find{ |m| m.membership_type.nil? }
            to_add_directly << memberships_association.build(@child_type => child)
          end
          
          # add a second entry for the given membership type
          if membership_type.present?
            membership =  memberships_association.
                            merge(child.__send__(:"group_memberships_as_#{@child_type}")).
                            as(membership_type).
                            first_or_initialize
            to_add_with_membership_type << membership unless membership.persisted?
          end

          child.__send__(:clear_association_cache)
        end

        clear_association_cache

        # then validate changes
        list_to_validate = to_add_directly + to_add_with_membership_type

        list_to_validate.each do |child|
          next if child.valid?

          if exception_on_invalidation
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
            membership_parent.__send__(:"group_memberships_as_#{@parent_type}") << memberships
            membership_parent.__send__(:clear_association_cache)
          end

        @parent
      end

      def children_association
        @parent_proxy.__send__(Groupify.__send__(:"#{@child_type}s_association_name"))
      end

      def memberships_association
        @parent.__send__(:"group_memberships_as_#{@parent_type}")
      end

      def clear_association_cache
        @parent.__send__(:clear_association_cache)
      end
    end
  end
end
