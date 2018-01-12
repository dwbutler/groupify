class University < Group
  has_member :students

  has_many :enrollments, inverse_of: :university, autosave: true
end
