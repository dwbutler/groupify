module Groupify
  module ActiveRecord
    class PolymorphicCollection
      include Enumerable
      extend Forwardable

      def initialize(source, &group_membership_filter)
        @source = source
        @collection = build_collection(&group_membership_filter)
      end

      def each(&block)
        @collection.map do |group_membership|
          group_membership.__send__(@source).tap(&block)
        end
      end

      def_delegators :@collection, :reload

      def count
        return @collection.size if @collection.loaded?

        queried_count = @collection.count
        # The `count` is a Hash when GROUP BY is used
        # PostgreSQL uses DISTINCT ON, which may be different
        queried_count = queried_count.keys.size if queried_count.is_a?(Hash)
        queried_count
      end

      alias_method :size, :count

      def_delegators :to_a, :[], :pretty_print

      alias_method :to_ary, :to_a
      alias_method :[], :to_a
      alias_method :empty?, :none?
      alias_method :blank?, :none?

      def inspect
        "#<#{self.class}:0x#{self.__id__.to_s(16)} #{to_a.inspect}>"
      end

    protected

      def build_collection(&group_membership_filter)
        collection = Groupify.group_membership_klass.where.not(:"#{@source}_id" => nil)
        collection = collection.instance_eval(&group_membership_filter) if block_given?
        collection = collection.includes(@source)

        distinct(collection)
      end

      def distinct(collection)
        id, type = "#{@source}_id", "#{@source}_type"

        if ActiveRecord.is_db?('postgres', 'pg')
          collection.select("DISTINCT ON (#{ActiveRecord.quote(id)}, #{ActiveRecord.quote(type)}) *")
        else
          collection.group([id, type])
        end
      end
    end
  end
end
