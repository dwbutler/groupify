class Group < ActiveRecord::Base
  groupify :group, members: [:users, :widgets, "namespaced/members"], default_members: :users
end
