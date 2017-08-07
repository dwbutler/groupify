module Groupify
  module ActiveRecord
    class PolymorphicCollection
      include Enumerable
      extend Forwardable

      def initialize(source, &group_membership_filter)
        @source = source
        @query = build_query(&group_membership_filter)
      end

      def each(&block)
        @query.map do |group_membership|
          group_membership.__send__(@source).tap(&block)
        end
      end

      def inspect
        "#<#{self.class}:0x#{self.__id__.to_s(16)} #{to_a.inspect}>"
      end

      def_delegators :@query, :reload

      def count
        return @query.size if @query.loaded?

        queried_count = @query.count
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

    protected

      def build_query(&group_membership_filter)
        query = Groupify.group_membership_klass.where.not(:"#{@source}_id" => nil)
        query = query.instance_eval(&group_membership_filter) if block_given?
        query = query.includes(@source)

        distinct(query)
      end

      def distinct(query)
        id, type = "#{@source}_id", "#{@source}_type"

        if ActiveRecord.is_db?('postgres', 'pg')
          query.select("DISTINCT ON (#{ActiveRecord.quote(id)}, #{ActiveRecord.quote(type)}) *")
        else
          query.group([id, type])
        end
      end
    end
  end
end
