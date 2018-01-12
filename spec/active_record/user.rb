class User < ActiveRecord::Base
  groupify :group_member
  groupify :named_group_member

  has_group :organizations, class_name: "Organization"
  has_group :classrooms, class_name: "Classroom"
end
