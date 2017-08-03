module Groupify
  module Mongoid

    # Usage:
    #    class User
    #      include Mongoid::Document
    #
    #      acts_as_named_group_member
    #      ...
    #    end
    #
    #    user.named_groups << :admin
    #
    module NamedGroupMember
      extend ActiveSupport::Concern
      include MemberScopedAs

      included do
        field :named_groups, type: Array, default: -> { [] }

        after_initialize do
          named_groups.extend NamedGroupCollection
          named_groups.member = self
        end
      end

      def in_named_group?(named_group, opts = {})
        named_groups.as(opts[:as]).include?(named_group)
      end

      def in_any_named_group?(*group_names)
        opts = group_names.extract_options!
        group_names.flatten.any?{ |named_group| in_named_group?(named_group, opts) }
      end

      def in_all_named_groups?(*named_groups)
        membership_type = named_groups.extract_options![:as]
        named_groups.flatten.to_set.subset? self.named_groups.as(membership_type).to_set
      end

      def in_only_named_groups?(*named_groups)
        membership_type = named_groups.extract_options![:as]
        named_groups.flatten.to_set == self.named_groups.as(membership_type).to_set
      end

      def shares_any_named_group?(other, opts = {})
        in_any_named_group?(other.named_groups, opts)
      end

      module ClassMethods
        def in_named_group(named_group, opts = {})
          in_any_named_group(named_group, opts)
        end

        def in_any_named_group(*named_groups)
          named_groups.flatten!
          named_groups.present? ? self.in(named_groups: named_groups) : none
        end

        def in_all_named_groups(*named_groups)
          named_groups.flatten!
          named_groups.present? ? where(:named_groups.all => named_groups) : none
        end

        def in_only_named_groups(*named_groups)
          named_groups.flatten!
          named_groups.present? ? where(named_groups: named_groups) : none
        end

        def shares_any_named_group(other, opts = {})
          in_any_named_group(other.named_groups, opts)
        end
      end
    end
  end
end
