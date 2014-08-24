module Groupify
  module Mongoid
    module Model
      extend ActiveSupport::Concern

      included do
        def none; where(:id => nil); end
      end

      module ClassMethods
        def groupify(type, opts = {})
          send("acts_as_#{type}", opts)
        end

        def acts_as_group(opts = {})
          include Groupify::Mongoid::Group

          if (member_klass = opts.delete :default_members)
            self.default_member_class = member_klass.to_s.classify.constantize
          end

          if (member_klasses = opts.delete :members)
            member_klasses.each do |member_klass|
              has_members(member_klass)
            end
          end
        end

        def acts_as_group_member(opts = {})
          @group_class_name = opts[:class_name] || 'Group'
          include Groupify::Mongoid::GroupMember
        end

        def acts_as_named_group_member(opts = {})
          include Groupify::Mongoid::NamedGroupMember
        end
      end
    end
  end
end

Mongoid::Document.send :include, Groupify::Mongoid::Model
