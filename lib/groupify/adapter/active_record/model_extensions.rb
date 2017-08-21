module Groupify
  module ActiveRecord
    module ModelExtensions
      def self.build_for(official_parent_type, options = {})
        module_name = "#{official_parent_type.to_s.classify}ModelExtensions"

        const_get(module_name.to_sym)
      rescue NameError
        # convert :group_member and :named_group_member
        parent_type = official_parent_type == :group ? :group : :member
        child_type = parent_type == :group ? :member : :group

        new_module = Module.new do
          extend ActiveSupport::Concern

          class_eval %Q(
            included do
              @default_#{child_type}_class_name = nil
              @default_#{child_type}s_association_name = nil
              @#{child_type}_klasses ||= Set.new

              has_many :group_memberships_as_#{parent_type},
                as: :#{parent_type},
                autosave: true,
                dependent: :destroy,
                class_name: Groupify.group_membership_class_name
            end

            module ClassMethods
              def configure_#{official_parent_type}!(opts = {})
                # Get defaults from parent class for STI
                self.default_#{child_type}_class_name = Groupify.superclass_fetch(self, :default_#{child_type}_class_name, Groupify.#{child_type}_class_name)
                self.default_#{child_type}s_association_name = Groupify.superclass_fetch(self, :default_#{child_type}s_association_name, Groupify.#{child_type}s_association_name)

                if (#{child_type}_association_names = opts.delete :#{child_type}s)
                  has_#{child_type}s(#{child_type}_association_names)
                end

                if (default_#{child_type}s = opts.delete :default_#{child_type}s)
                  self.default_#{child_type}_class_name = default_#{child_type}s.to_s.classify
                  # Only use as the association name if none specified (backwards-compatibility)
                  self.default_#{child_type}s_association_name ||= default_#{child_type}s
                end

                if (#{child_type}_class_name = opts.delete :#{child_type}_class_name)
                  self.default_#{child_type}_class_name = #{child_type}_class_name
                end

                if default_#{child_type}s_association_name
                  has_#{child_type}(default_#{child_type}s_association_name,
                    source_type: ActiveRecord.base_class_name(default_#{child_type}_class_name),
                    class_name: default_#{child_type}_class_name
                  )
                end
              end

              def default_#{child_type}_class_name
                @default_#{child_type}_class_name ||= Groupify.#{child_type}_class_name
              end

              def default_#{child_type}_class_name=(klass)
                @default_#{child_type}_class_name = klass
              end

              def default_#{child_type}s_association_name
                @default_#{child_type}s_association_name ||= Groupify.#{child_type}s_association_name
              end

              def default_#{child_type}s_association_name=(name)
                @default_#{child_type}s_association_name = name && name.to_sym
              end

              # Returns the #{child_type} classes defined for this class, as well as for the super classes
              def #{child_type}_classes
                (@#{child_type}_klasses ||= Set.new).merge(Groupify.superclass_fetch(self, :#{child_type}_classes, []))
              end

              def has_#{child_type}s(*association_names, &extension)
                association_names.flatten.each do |association_name|
                  has_#{child_type}(association_name, &extension)
                end
              end

              def has_#{child_type}(association_name, opts = {}, &extension)
                #{child_type}_klass = ActiveRecord.create_children_association(self, association_name,
                  opts.merge(
                    through: :group_memberships_as_#{parent_type},
                    source: :#{child_type},
                    default_base_class: default_#{child_type}_class_name
                  ),
                  &extension
                )

                (@#{child_type}_klasses ||= Set.new) << #{child_type}_klass.to_s.constantize
              rescue NameError
                Rails.logger.warn "Error: Unable to add \#{#{child_type}_klass} to @#{child_type}_klasses"
              ensure
                self
              end
            end

            def polymorphic_#{child_type}s(&group_membership_filter)
              PolymorphicRelation.new(self, :#{child_type}, &group_membership_filter)
            end

            def #{child_type}_classes
              self.class.#{child_type}_classes
            end

            # returns `nil` membership type with results
            def membership_types_for_#{child_type}(record)
              group_memberships_as_#{parent_type}.
                for_#{child_type}s([record]).
                select(:membership_type).
                distinct.
                pluck(:membership_type).
                sort_by(&:to_s)
            end

            def find_memberships_for_#{child_type}s(children)
              group_memberships_as_#{parent_type}.for_#{child_type}s(children)
            end

            def add_#{child_type}s(children, opts = {})
              return self if children.none?

              clear_association_cache_for(self)

              membership_type = opts[:as]

              to_add_directly = []
              to_add_with_membership_type = []

              already_children = find_memberships_for_#{child_type}s(children).includes(:#{child_type}).group_by{ |membership| membership.#{child_type} }

              # first prepare changes
              children.each do |child|
                # add to collection without membership type
                unless already_children[child] && already_children[child].find{ |m| m.membership_type.nil? }
                  to_add_directly << group_memberships_as_#{parent_type}.build(#{child_type}: child)
                end

                # add a second entry for the given membership type
                if membership_type.present?
                  membership =  group_memberships_as_#{parent_type}.
                                  merge(child.group_memberships_as_#{child_type}).
                                  as(membership_type).
                                  first_or_initialize
                  to_add_with_membership_type << membership unless membership.persisted?
                end

                clear_association_cache_for(child)
              end

              clear_association_cache_for(self)

              # then validate changes
              list_to_validate = to_add_directly + to_add_with_membership_type

              list_to_validate.each do |child|
                next if child.valid?

                if opts[:exception_on_invalidation]
                  raise ::ActiveRecord::RecordInvalid.new(child)
                else
                  return false
                end
              end

              # create memberships without membership type
              group_memberships_as_#{parent_type} << to_add_directly

              # create memberships with membership type
              to_add_with_membership_type.
                group_by{ |membership| membership.#{parent_type} }.
                each do |membership_parent, memberships|
                  membership_parent.group_memberships_as_#{parent_type} << memberships
                  clear_association_cache_for(membership_parent)
                end

              self
            end
          )

        protected

          def clear_association_cache_for(record)
            record.__send__(:clear_association_cache)
          end
        end

        self.const_set(module_name, new_module)
      end
    end
  end
end
