require 'active_record'
require 'set'

module Groupify
  module ActiveRecord
    require 'groupify/adapter/active_record/model'

    autoload :Group, 'groupify/adapter/active_record/group'
    autoload :GroupMember, 'groupify/adapter/active_record/group_member'
    autoload :GroupMembership, 'groupify/adapter/active_record/group_membership'
    autoload :NamedGroupCollection, 'groupify/adapter/active_record/named_group_collection'
    autoload :NamedGroupMember, 'groupify/adapter/active_record/named_group_member'

    def self.quote(model_class, column_name)
      "#{model_class.quoted_table_name}.#{::ActiveRecord::Base.connection.quote_column_name(column_name)}"
    end

    def self.find_memberships_for(parent, children, membership_type = nil)
      parent_type, child_type = detect_types_from_parent(parent)

      query = parent.__send__(:"group_memberships_as_#{parent_type}").__send__(:"for_#{child_type}s", children)
      query = query.as(membership_type) if membership_type
      query
    end

    def self.add_children_to_parent(parent, children, options = {})
      parent_type, child_type = detect_types_from_parent(parent)

      membership_type = options[:as]
      exception_on_invalidation = options[:exception_on_invalidation]

      return parent if children.none?

      parent.__send__(:clear_association_cache)

      memberships_association = parent.__send__(:"group_memberships_as_#{parent_type}")

      to_add_directly = []
      to_add_with_membership_type = []

      already_children = find_memberships_for(parent, children).includes(child_type).map(&child_type).uniq
      children -= already_children

      # first prepare changes
      children.each do |child|
        # add to collection without membership type
        to_add_directly << memberships_association.build(child_type => child)
        # add a second entry for the given membership type
        if membership_type
          membership =  memberships_association.
                          merge(child.__send__(:"group_memberships_as_#{child_type}")).
                          as(membership_type).
                          first_or_initialize
          to_add_with_membership_type << membership unless membership.persisted?
        end
        parent.__send__(:clear_association_cache)
      end

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
        group_by{ |membership| membership.__send__(parent_type) }.
        each do |membership_parent, memberships|
          membership_parent.__send__(:"group_memberships_as_#{parent_type}") << memberships
          membership_parent.__send__(:clear_association_cache)
        end

      parent
    end

  protected

    def self.detect_types_from_parent(parent)
      if parent.is_a?(Groupify::ActiveRecord::Group)
        [:group, :member]
      else
        [:member, :group]
      end
    end
  end
end
