class CustomUser < ActiveRecord::Base
  groupify :group_member
  groupify :named_group_member
end
