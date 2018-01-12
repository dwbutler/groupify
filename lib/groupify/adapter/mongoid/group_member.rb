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
        @default_group_class_name = nil
        @default_groups_association_name = nil

        class GroupMembership
          include ::Mongoid::Document

          embedded_in :member, polymorphic: true

          field :named_groups, type: Array, default: -> { [] }

          after_initialize do
            named_groups.extend NamedGroupCollection
          end

          field :as, as: :membership_type, type: String
        end

        embeds_many :group_memberships, class_name: GroupMembership.to_s, as: :member do
          def as(membership_type)
            where(membership_type: membership_type)
          end
        end
      end

      def in_group?(group, opts = {})
        group.present? ? groups.as(opts[:as]).include?(group) : false
      end

      def in_any_group?(*groups)
        opts = groups.extract_options!
        groups.flatten.any?{ |group| in_group?(group, opts) }
      end

      def in_all_groups?(*groups)
        membership_type = groups.extract_options![:as]
        groups.flatten.to_set.subset? self.groups.as(membership_type).to_set
      end

      def in_only_groups?(*groups)
        membership_type = groups.extract_options![:as]
        groups.to_set == self.groups.as(membership_type).to_set
      end

      def shares_any_group?(other, opts = {})
        in_any_group?(other.groups.to_a, opts)
      end

      module ClassMethods
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

        def default_group_class_name
          @default_group_class_name ||= Groupify.group_class_name
        end

        def default_group_class_name=(klass)
          @default_group_class_name = klass
        end

        def default_groups_association_name
          @default_groups_association_name ||= Groupify.groups_association_name
        end

        def default_groups_association_name=(name)
          @default_groups_association_name = name && name.to_sym
        end

        def has_groups(*association_names)
          association_names.flatten.each do |association_name|
            has_group(association_name)
          end
        end

        def has_group(association_name, opts = {})
          association_class, association_name = Groupify.infer_class_and_association_name(association_name)
          opts = {autosave: true, dependent: :nullify, inverse_of: nil}.merge(opts)
          model_klass = opts[:class_name] || association_class || default_base_class

          has_and_belongs_to_many association_name, opts do
            def as(membership_type)
              # `membership_type.present?` causes tests to fail for `MongoidManager` class....
              return self unless membership_type

              group_ids = base.group_memberships.as(membership_type).first.group_ids

              if group_ids.present?
                self.and(:id.in => group_ids)
              else
                self.and(:id => nil)
              end
            end

            def destroy(*groups)
              delete(*groups)
            end

            def delete(*groups)
              membership_type = groups.extract_options![:as]
              groups.flatten!

              if membership_type.present?
                base.group_memberships.as(membership_type).each do |membership|
                  membership.groups.delete(*groups)
                end
              else
                super(*groups)
              end
            end
          end

          GroupMembership.send(:has_and_belongs_to_many,
            association_name, {
              class_name: model_klass,
              inverse_of: nil}.
            merge(opts.slice(:class_name))
          )
        end
      end
    end
  end
end
