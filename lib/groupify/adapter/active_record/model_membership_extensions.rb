module Groupify
  module ActiveRecord
    module ModelMembershipExtensions
      def self.build_for(parent_type, options = {})
        module_name = "#{parent_type.to_s.classify}MembershipExtensions"

        const_get(module_name.to_sym)
      rescue NameError
        # convert :group_member and :named_group_member
        parent_type = :member unless parent_type == :group
        child_type = parent_type == :group ? :member : :group

        new_module = Module.new do
          class_eval %Q(
            def find_memberships_for_#{child_type}s(children, opts = {})
              group_memberships_as_#{parent_type}.for_#{child_type}s(children).as(opts[:as])
            end

            def add_#{child_type}s(children, opts = {})
              return self if children.none?

              clear_association_cache_for(self)

              membership_type = opts[:as]

              to_add_directly = []
              to_add_with_membership_type = []

              already_children = find_memberships_for_#{child_type}s(children).includes(@child_type).group_by{ |membership| membership.#{child_type} }

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

          protected

            def clear_association_cache_for(record)
              record.__send__(:clear_association_cache)
            end
          )
        end

        self.const_set(module_name, new_module)
      end
    end
  end
end
