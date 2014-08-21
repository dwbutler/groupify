require 'mongoid'
require 'set'

module Groupify
  module Mongoid
    require 'groupify/adapter/mongoid/model'

    autoload :Group, 'groupify/adapter/mongoid/group'
    autoload :GroupMember, 'groupify/adapter/mongoid/group_member'
    autoload :MemberScopedAs, 'groupify/adapter/mongoid/member_scoped_as'
    autoload :NamedGroupCollection, 'groupify/adapter/mongoid/named_group_collection'
    autoload :NamedGroupMember, 'groupify/adapter/mongoid/named_group_member'
  end
end


