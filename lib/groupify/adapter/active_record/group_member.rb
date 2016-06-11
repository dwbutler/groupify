module Groupify
  module ActiveRecord

    # Usage:
    #    class User < ActiveRecord::Base
    #        groupify :group_member
    #        ...
    #    end
    #
    #    user.groups << group
    #
    module GroupMember
      extend ActiveSupport::Concern

      included do
        unless respond_to?(:group_memberships_as_member)
          has_many :group_memberships_as_member,
                   as: :member,
                   autosave: true,
                   dependent: :destroy,
                   class_name: Groupify.group_membership_class_name
        end

      end

      module GroupAssociationExtensions
        def as(membership_type)
          return self unless membership_type
          where(group_memberships: {membership_type: membership_type})
        end

        def delete(*args)
          opts = args.extract_options!
          groups = args.flatten

          if opts[:as]
            proxy_association.owner.group_memberships_as_member.where(group_id: groups.map(&:id)).as(opts[:as]).delete_all
          else
            super(*groups)
          end
        end

        def destroy(*args)
          opts = args.extract_options!
          groups = args.flatten

          if opts[:as]
            proxy_association.owner.group_memberships_as_member.where(group_id: groups.map(&:id)).as(opts[:as]).destroy_all
          else
            super(*groups)
          end
        end
      end

      def in_group?(group, opts={})
        criteria = {group_id: group.id}

        if opts[:as]
          criteria.merge!(membership_type: opts[:as])
        end

        group_memberships_as_member.exists?(criteria)
      end

      def in_any_group?(*args)
        opts = args.extract_options!
        groups = args

        groups.flatten.each do |group|
          return true if in_group?(group, opts)
        end
        return false
      end

      def in_all_groups?(*args)
        opts = args.extract_options!
        groups = args.flatten

        groups.to_set.subset? self.groups.as(opts[:as]).to_set
      end

      def in_only_groups?(*args)
        opts = args.extract_options!
        groups = args.flatten

        groups.to_set == self.groups.as(opts[:as]).to_set
      end

      def shares_any_group?(other, opts={})
        in_any_group?(other.groups, opts)
      end

      module ClassMethods
        def as(membership_type)
          joins(:group_memberships_as_member).where(group_memberships: { membership_type: membership_type })
        end

        def in_group(group)
          return none unless group.present?

          joins(:group_memberships_as_member).where(group_memberships: { group_id: group.id }).uniq
        end

        def in_any_group(*groups)
          groups = groups.flatten
          return none unless groups.present?

          joins(:group_memberships_as_member).where(group_memberships: { group_id: groups.map(&:id) }).uniq
        end

        def in_all_groups(*groups)
          groups = groups.flatten
          return none unless groups.present?

          joins(:group_memberships_as_member).
              group("#{quoted_table_name}.#{connection.quote_column_name('id')}").
              where(group_memberships: {group_id: groups.map(&:id)}).
              having("COUNT(#{reflect_on_association(:group_memberships_as_member).klass.quoted_table_name}.#{connection.quote_column_name('group_id')}) = ?", groups.count).
              uniq
        end

        def in_only_groups(*groups)
          groups = groups.flatten
          return none unless groups.present?

          joins(:group_memberships_as_member).
              group("#{quoted_table_name}.#{connection.quote_column_name('id')}").
              having("COUNT(DISTINCT #{reflect_on_association(:group_memberships_as_member).klass.quoted_table_name}.#{connection.quote_column_name('group_id')}) = ?", groups.count).
              uniq
        end

        def shares_any_group(other)
          in_any_group(other.groups)
        end

        def belongs_to_groups(*names)
          Array.wrap(names.flatten).each do |name|
            belongs_to_group(name)
          end
        end

        def belongs_to_group(args)
          if args.respond_to?(:to_s)
            class_name = args
            association_name = nil
          elsif args.respond_to?(:[])
            opts = args.extract_options!
            class_name = opts[:class_name]
            association_name = opts[:association_name]
          end

          klass = class_name.to_s.classify.constantize
          register_group_class(klass)
          associate_group_class(klass, association_name)
        end

        def register_group_class(group_class)
          group_classes << group_class
        end

        def group_classes
          @group_classes ||= Set.new
        end

        def default_group_class
          @default_group_class ||= (Group rescue false)
        end

        def default_group_class=(klass)
          @default_group_class = klass
        end

        def associate_group_class(group_klass, association_name = nil)
          define_group_association(group_klass, association_name)

          if group_klass == default_group_class
            define_group_association(group_klass, :groups)
          end
        end

        def define_group_association(group_klass, association_name = nil)
          association_name ||= group_klass.model_name.plural.to_sym
          source_type = group_klass.base_class

          if ActiveSupport::VERSION::MAJOR > 3
            has_many association_name,
                     ->{ uniq },
                     through: :group_memberships_as_member,
                     as: :group,
                     source_type: source_type,
                     extend: GroupAssociationExtensions
          else
            has_many association_name,
                     uniq: true,
                     through: :group_memberships_as_member,
                     as: :group,
                     source_type: source_type,
                     extend: GroupAssociationExtensions
          end
        end
      end
    end
  end
end
