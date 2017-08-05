class CustomGroup < ActiveRecord::Base
  groupify :group, members: [:custom_users]
end
