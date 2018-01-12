class Student < ActiveRecord::Base
  groupify :group
  groupify :group_member
  has_group :universities

  has_many :enrollments, inverse_of: :student
end
