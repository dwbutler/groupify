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

      def in_named_group?(named_group, opts={})
        named_groups.as(opts[:as]).include?(named_group)
      end

      def in_any_named_group?(*args)
        opts = args.extract_options!
        group_names = args.flatten

        group_names.each do |named_group|
          return true if in_named_group?(named_group)
        end

        return false
      end

      def in_all_named_groups?(*args)
        opts = args.extract_options!
        named_groups = args.flatten.to_set

        named_groups.subset? self.named_groups.as(opts[:as]).to_set
      end

      def in_only_named_groups?(*args)
        opts = args.extract_options!
        named_groups = args.flatten.to_set
        named_groups == self.named_groups.as(opts[:as]).to_set
      end

      def shares_any_named_group?(other, opts={})
        in_any_named_group?(other.named_groups, opts)
      end

      module ClassMethods
        def in_named_group(named_group, opts={})
          in_any_named_group(named_group, opts)
        end

        def in_any_named_group(*named_groups)
          named_groups.flatten!
          return none unless named_groups.present?

          self.in(named_groups: named_groups.flatten)
        end

        def in_all_named_groups(*named_groups)
          named_groups.flatten!
          return none unless named_groups.present?

          where(:named_groups.all => named_groups.flatten)
        end

        def in_only_named_groups(*named_groups)
          named_groups.flatten!
          return none unless named_groups.present?

          where(named_groups: named_groups.flatten)
        end

        def shares_any_named_group(other, opts={})
          in_any_named_group(other.named_groups, opts)
        end
      end
    end
  end
end
