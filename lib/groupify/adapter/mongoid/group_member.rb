module Groupify
  module Mongoid

    # Usage:
    #    class User
    #      include Mongoid::Document
    #
    #      acts_as_group_member
    #      ...
    #    end
    #
    #    user.groups << group
    #
    module GroupMember
      extend ActiveSupport::Concern
      include MemberScopedAs

      included do
        has_and_belongs_to_many :groups, autosave: true, dependent: :nullify, inverse_of: nil, class_name: @group_class_name do
          def as(membership_type)
            return self unless membership_type
            group_ids = base.group_memberships.as(membership_type).first.group_ids

            if group_ids.present?
              self.and(:id.in => group_ids)
            else
              self.and(:id => nil)
            end
          end

          def destroy(*args)
            delete(*args)
          end

          def delete(*args)
            opts = args.extract_options!
            groups = args.flatten


            if opts[:as]
              base.group_memberships.as(opts[:as]).each do |membership|
                membership.groups.delete(*groups)
              end
            else
              super(*groups)
            end
          end
        end

        class GroupMembership
          include ::Mongoid::Document

          embedded_in :member, polymorphic: true

          field :named_groups, type: Array, default: -> { [] }

          after_initialize do
            named_groups.extend NamedGroupCollection
          end

          field :as, as: :membership_type, type: String
        end

        GroupMembership.send :has_and_belongs_to_many, :groups, class_name: @group_class_name, inverse_of: nil

        embeds_many :group_memberships, class_name: GroupMembership.to_s, as: :member do
          def as(membership_type)
            where(membership_type: membership_type.to_s)
          end
        end
      end

      def in_group?(group, opts={})
        groups.as(opts[:as]).include?(group)
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
        groups = args

        groups.flatten.to_set.subset? self.groups.as(opts[:as]).to_set
      end

      def in_only_groups?(*args)
        opts = args.extract_options!
        groups = args.flatten

        groups.to_set == self.groups.as(opts[:as]).to_set
      end

      def shares_any_group?(other, opts={})
        in_any_group?(other.groups.to_a, opts)
      end

      module ClassMethods
        def group_class_name; @group_class_name ||= 'Group'; end
        def group_class_name=(klass);  @group_class_name = klass; end

        def in_group(group)
          group.present? ? self.in(group_ids: group.id) : none
        end

        def in_any_group(*groups)
          groups.present? ? self.in(group_ids: groups.flatten.map(&:id)) : none
        end

        def in_all_groups(*groups)
          groups.present? ? where(:group_ids.all => groups.flatten.map(&:id)) : none
        end

        def in_only_groups(*groups)
          groups.present? ? where(:group_ids => groups.flatten.map(&:id)) : none
        end

        def shares_any_group(other)
          in_any_group(other.groups.to_a)
        end

      end
    end
  end
end
