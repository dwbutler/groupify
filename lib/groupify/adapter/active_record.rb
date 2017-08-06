require 'active_record'
require 'set'

module Groupify
  module ActiveRecord
    require 'groupify/adapter/active_record/model'

    autoload :Group, 'groupify/adapter/active_record/group'
    autoload :GroupMember, 'groupify/adapter/active_record/group_member'
    autoload :GroupMembership, 'groupify/adapter/active_record/group_membership'
    autoload :PolymorphicCollection, 'groupify/adapter/active_record/polymorphic_collection'
    autoload :PolymorphicRelation, 'groupify/adapter/active_record/polymorphic_relation'
    autoload :NamedGroupCollection, 'groupify/adapter/active_record/named_group_collection'
    autoload :NamedGroupMember, 'groupify/adapter/active_record/named_group_member'

    def self.quote(model_class, column_name)
      "#{model_class.quoted_table_name}.#{::ActiveRecord::Base.connection.quote_column_name(column_name)}"
    end

    # Pass in record, class, or string
    def self.base_class_name(model_class, &default_base_class)
      return if model_class.nil?

      if model_class.is_a?(::ActiveRecord::Base)
        model_class = model_class.class
      elsif !(model_class.is_a?(Class) && model_class < ::ActiveRecord::Base)
        model_class = model_class.to_s.constantize
      end

      model_class.base_class.name
    rescue NameError
      return base_class_name(yield) if block_given?
      return model_class.to_s if Groupify.ignore_base_class_inference_errors

      raise
    end

    def self.memberships_merge(scope, options = {})
      parent, parent_type, _ = infer_parent_and_types(scope, options[:parent_type])

      criteria = [parent.joins(:"group_memberships_as_#{parent_type}")]
      criteria << options[:criteria] if options[:criteria]
      criteria << Groupify.group_membership_klass.instance_eval(&options[:filter]) if options[:filter]

      # merge all criteria together
      criteria.compact.reduce(:merge)
    end

    def self.find_memberships_for(parent, children, options = {})
      parent, parent_type, child_type = infer_parent_and_types(parent, options[:parent_type])

      parent.
        __send__(:"group_memberships_as_#{parent_type}").
        __send__(:"for_#{child_type}s", children).
        as(options[:as])
    end

    def self.add_children_to_parent(parent, children, options = {})
      parent, parent_type, child_type = infer_parent_and_types(parent, options[:parent_type])

      membership_type = options[:as]
      exception_on_invalidation = options[:exception_on_invalidation]

      return parent if children.none?

      parent.__send__(:clear_association_cache)

      memberships_association = parent.__send__(:"group_memberships_as_#{parent_type}")

      to_add_directly = []
      to_add_with_membership_type = []

      already_children = find_memberships_for(parent, children, parent_type: parent_type).includes(child_type).map(&child_type).uniq
      children -= already_children

      # first prepare changes
      children.each do |child|
        # add to collection without membership type
        to_add_directly << memberships_association.build(child_type => child)
        # add a second entry for the given membership type
        if membership_type.present?
          membership =  memberships_association.
                          merge(child.__send__(:"group_memberships_as_#{child_type}")).
                          as(membership_type).
                          first_or_initialize
          to_add_with_membership_type << membership unless membership.persisted?
        end

        child.__send__(:clear_association_cache)
      end

      parent.__send__(:clear_association_cache)

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

    # Takes an association or model as the parent. If a model
    # is passed in, the `default_parent_type` option needs
    # to be passed in if the model is both a group and group member.
    #
    # Can't detect based on included `Group` or `GroupMember`
    # modules because a model can be both a group and a gorup member.
    def self.infer_parent_and_types(parent, default_parent_type = nil)
      parent_is_group = true

      # Association assumed to be a `has_many through`
      if parent.respond_to?(:through_reflection)
        parent_is_group = (parent.through_reflection.name == :group_memberships_as_group)
        parent = parent.owner
      elsif default_parent_type
        parent_is_group = (default_parent_type == :group)
      else
        parent_is_group  = parent.class.include?(Groupify::ActiveRecord::Group)
        detected_modules = [parent_is_group, parent.class.include?(Groupify::ActiveRecord::GroupMember)].count{ |bool| bool == true }

        if detected_modules == 0
          raise "The specified record is neither group nor group member."
        elsif detected_modules == 2
          raise "Can't infer whether record should be treated as group or group member because it is configured as both. Pass the `default_parent_type` option to specify which it should be treated as."
        end
      end

      if parent_is_group
        [parent, :group, :member]
      else
        [parent, :member, :group]
      end
    end
  end
end
