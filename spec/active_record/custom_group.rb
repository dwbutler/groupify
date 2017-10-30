class CustomGroup < ActiveRecord::Base
  groupify :group, members: [:custom_users]
  groupify :group_member
end
