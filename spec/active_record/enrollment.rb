class Enrollment < ActiveRecord::Base
  belongs_to :parent, inverse_of: :enrollments
  belongs_to :student, inverse_of: :enrollments, autosave: true
  belongs_to :university, inverse_of: :enrollments
end
