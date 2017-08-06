module Groupify
  module ActiveRecord
    class PolymorphicCollection
      include Enumerable
      extend Forwardable

      def initialize(source, &query_filter)
        @source = source
        @query = build_query(&query_filter)
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
        @query.loaded? ? @query.size : @query.count.keys.size
      end

      alias_method :size, :count

      def_delegators :to_a, :[], :pretty_print

      alias_method :to_ary, :to_a
      alias_method :[], :to_a
      alias_method :empty?, :none?
      alias_method :blank?, :none?

    protected

      def build_query(&query_filter)
        query = Groupify.group_membership_klass.where.not(:"#{@source}_id" => nil)
        query = yield(query) if block_given?
        query = query.group(["#{@source}_id", "#{@source}_type"]).includes(@source)
        query
      end
    end
  end
end
