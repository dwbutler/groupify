module Groupify
  module ActiveRecord
    class ParentProxy

      def self.configure(klass, parent_type, opts = {})
        child_type = parent_type == :group ? :member : :group

        if parent_type == :member
          member_backwards_compatibility = %[
            # Deprecated: for backwards-compatibility
            if (group_class_name = opts.delete :group_class_name)
              self.default_group_class_name = group_class_name
            end
          ]
        end

        klass.class_eval %[
          opts = #{opts.inspect}
          # Get defaults from parent class for STI
          self.default_#{child_type}_class_name = Groupify.superclass_fetch(self, :default_#{child_type}_class_name, Groupify.#{child_type}_class_name)
          self.default_#{child_type}s_association_name = Groupify.superclass_fetch(self, :default_#{child_type}s_association_name, Groupify.#{child_type}s_association_name)

          if (#{child_type}_association_names = opts.delete :#{child_type}s)
            has_#{child_type}s(#{child_type}_association_names)
          end

          #{member_backwards_compatibility}

          if (default_#{child_type}s = opts.delete :default_#{child_type}s)
            self.default_#{child_type}_class_name = default_#{child_type}s.to_s.classify
            # Only use as the association name if none specified (backwards-compatibility)
            self.default_#{child_type}s_association_name ||= default_#{child_type}s
          end

          if default_#{child_type}s_association_name
            has_#{child_type}(default_#{child_type}s_association_name,
              source_type: ActiveRecord.base_class_name(default_#{child_type}_class_name),
              class_name: default_#{child_type}_class_name
            )
          end
        ]

        # children_name = :"#{child_type}s"
        # default_children_type = :"default_#{children_name}"
        # default_association_method = :"#{default_children_type}_association_name"
        # has_child_method = :"has_#{children_name}"
        #
        # # Get defaults from parent class for STI
        # [:class_name, :association_name].each do |setting|
        #   default_setting    = Groupify.__send__(:"#{child_type}_#{setting}")
        #   superclass_setting = Groupify.superclass_fetch(klass, :"#{default_children_type}_#{setting}", default_setting)
        #
        #   klass.__send__(:"#{default_children_type}_#{setting}=", superclass_setting)
        # end
        #
        # if (association_names = opts.delete children_name)
        #   klass.__send__(has_child_method, association_names)
        # end
        #
        # if (association_name = opts.delete default_children_type)
        #   klass.__send__(:"default_#{child_type}_class_name=", association_name.to_s.classify)
        #   # Only use as the association name if none specified (backwards-compatibility)
        #   unless klass.__send__(default_association_method)
        #     klass.__send__(:"#{default_association_method}=", association_name)
        #   end
        # end
        #
        # if (default_association_name = klass.__send__(default_association_method))
        #   default_class_name = klass.default_member_class_name
        #
        #   klass.__send__(has_child_method, default_association_name,
        #     source_type: ActiveRecord.base_class_name(default_class_name),
        #     class_name: default_class_name
        #   )
        # end
      end

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
        association_name = @parent.class.__send__(:"default_#{@child_type}s_association_name")

        @parent.__send__(association_name) if association_name
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
