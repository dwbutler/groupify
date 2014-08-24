module Groupify
  module ActiveRecord

    # Usage:
    #    class User < ActiveRecord::Base
    #        acts_as_group_member
    #        ...
    #    end
    #
    #    user.groups << group
    #
    module GroupMember
      extend ActiveSupport::Concern

      included do
        unless respond_to?(:group_memberships)
          has_many :group_memberships, as: :member, autosave: true, dependent: :destroy
        end

        if ActiveSupport::VERSION::MAJOR > 3
          has_many :groups, ->{ uniq }, through: :group_memberships, class_name: @group_class_name, extend: GroupAssociationExtensions
        else
          has_many :groups, uniq: true, through: :group_memberships, class_name: @group_class_name, extend: GroupAssociationExtensions
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
            proxy_association.owner.group_memberships.where(group_id: groups.map(&:id)).as(opts[:as]).delete_all
          else
            super(*groups)
          end
        end

        def destroy(*args)
          opts = args.extract_options!
          groups = args.flatten

          if opts[:as]
            proxy_association.owner.group_memberships.where(group_id: groups.map(&:id)).as(opts[:as]).destroy_all
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

        group_memberships.exists?(criteria)
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
        def group_class_name; @group_class_name ||= 'Group'; end
        def group_class_name=(klass);  @group_class_name = klass; end

        def as(membership_type)
          joins(:group_memberships).where(group_memberships: { membership_type: membership_type })
        end

        def in_group(group)
          return none unless group.present?

          joins(:group_memberships).where(group_memberships: { group_id: group.id }).uniq
        end

        def in_any_group(*groups)
          groups = groups.flatten
          return none unless groups.present?

          joins(:group_memberships).where(group_memberships: { group_id: groups.map(&:id) }).uniq
        end

        def in_all_groups(*groups)
          groups = groups.flatten
          return none unless groups.present?

          joins(:group_memberships).
              group(:"group_memberships.member_id").
              where(:group_memberships => {:group_id => groups.map(&:id)}).
              having("COUNT(group_memberships.group_id) = #{groups.count}").
              uniq
        end

        def in_only_groups(*groups)
          groups = groups.flatten
          return none unless groups.present?

          joins(:group_memberships).
              group(:"group_memberships.member_id").
              having("COUNT(DISTINCT group_memberships.group_id) = #{groups.count}").
              uniq
        end

        def shares_any_group(other)
          in_any_group(other.groups)
        end

      end
    end
  end
end
