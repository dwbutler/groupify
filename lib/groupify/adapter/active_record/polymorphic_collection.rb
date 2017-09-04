module Groupify
  module ActiveRecord
    # This `PolymorphicCollection` class acts as a facade to mimic the querying
    # capabilities of an ActiveRecord::Relation while internally returning results
    # which are actually retrieved from a method or association on the actual
    # results. In other words, this class queries on the "join record"
    # and returns records from one of the associations that would have
    # to otherwise query across multiple tables. To avoid N+1, `includes`
    # is added to the query chain to make things more efficient.
    class PolymorphicCollection
      include Enumerable
      extend Forwardable

      attr_reader :source

      def initialize(source_name, &group_membership_filter)
        @source_name = source_name
        @collection = build_collection(&group_membership_filter)
      end

      def each(&block)
        distinct_compat.map do |group_membership|
          group_membership.__send__(@source_name).tap(&block)
        end
      end

      def_delegators :@collection, :reload

      def count
        @collection.loaded? ? @collection.size : count_compat
      end

      alias_method :size, :count

      def_delegators :to_a, :[], :pretty_print

      alias_method :to_ary, :to_a
      alias_method :empty?, :none?
      alias_method :blank?, :none?

      def inspect
        "#<#{self.class}:0x#{self.__id__.to_s(16)} #{to_a.inspect}>"
      end

    protected

      def build_collection(&group_membership_filter)
        collection = Groupify.group_membership_klass.where.not(:"#{@source_name}_id" => nil)
        collection = collection.instance_eval(&group_membership_filter) if block_given?
        collection = collection.includes(@source_name)

        collection
      end

      def distinct_compat
        id, type = ActiveRecord.quote("#{@source_name}_id"), ActiveRecord.quote("#{@source_name}_type")

        # Workaround to "group by" multiple columns in PostgreSQL
        if ActiveRecord.is_db?('postgres')
          @collection.select("DISTINCT ON (#{id}, #{type}) *")
        else
          @collection.group([id, type])
        end
      end

      def count_compat
        # Workaround to "count distinct" on multiple columns in PostgreSQL
        # (uses different syntax when aggregating distinct)
        if ActiveRecord.is_db?('postgres')
          id, type = ActiveRecord.quote("#{@source_name}_id"), ActiveRecord.quote("#{@source_name}_type")

          queried_count = @collection.select("DISTINCT (#{id}, #{type})").count
        else
          queried_count = distinct_compat.count
          # The `count` is a Hash when GROUP BY is used
          queried_count = queried_count.keys.size if queried_count.is_a?(Hash)
        end

        queried_count
      end
    end
  end
end
