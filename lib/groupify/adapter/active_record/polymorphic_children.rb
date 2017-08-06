module Groupify
  module ActiveRecord
    class PolymorphicChildren
      include Enumerable
      extend Forwardable
      include CollectionExtensions

      def initialize(parent, parent_type, child_class_for_builder = nil, &query_filter)
        @collection_parent, @collection_parent_type = parent, parent_type
        @child_type = parent_type == :group ? :member : :group
        @collection = build_query(&query_filter)
      end

      def each(&block)
        @collection.map do |group_membership|
          group_membership.__send__(@child_type).tap(&block)
        end
      end

      def inspect
        "#<#{self.class}:0x#{self.__id__.to_s(16)} @collection_parent=#{@collection_parent.inspect} @collection_parent_type=#{@collection_parent_type.inspect} #{to_a.inspect}>"
      end

      def_delegators :collection, :reload

      def as(membership_type)
        @collection = super
        @collection.reset

        self
      end

      def count
        @collection.loaded? ? @collection.size : @collection.count.keys.size
      end

      alias_method :size, :count

      # When trying to create a new record for this collection,
      # create it on the `member.default_groups` or `group.default_members`
      # association.
      def_delegators :default_association, :build, :create, :create!
      def_delegators :to_a, :[]

      alias_method :to_ary, :to_a
      alias_method :[], :take
      alias_method :empty?, :none?
      alias_method :blank?, :none?

    protected

      attr_reader :collection, :collection_parent, :collection_parent_type

      def default_association
        @collection_parent.__send__(Groupify.__send__(:"#{@child_type}s_association_name"))
      end

      def build_query(&query_filter)
        query = @collection_parent.__send__(:"group_memberships_as_#{@collection_parent_type}").where.not(group_id: nil)
        query = query.instance_eval(&query_filter) if block_given?
        query = query.group(["#{@child_type}_id", "#{@child_type}_type"]).includes(@child_type)
        query
      end
    end
  end
end
