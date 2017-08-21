class Parent < ActiveRecord::Base
  groupify :group_member
  groupify :named_group_member
  has_group :personas

  has_many :enrollments, inverse_of: :some_user
  has_many :enrolled_students, ->{ distinct }, through: :enrollments, source: :student
end
