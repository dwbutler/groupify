class Classroom < ActiveRecord::Base
  groupify :group
  groupify :group_member
end
