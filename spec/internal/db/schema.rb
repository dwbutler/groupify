ActiveRecord::Schema.define(version: 0) do
  create_table :groups do |t|
    t.string     :type
    t.string     :name
  end

  create_table :group_memberships do |t|
    t.references :member, polymorphic: true, index: true, null: false
    t.references :group, polymorphic: true, index: true
    t.string     :group_name, index: true
    t.string     :membership_type
  end

  create_table :users do |t|
    t.string   :name
    t.string   :type
  end

  create_table :widgets do |t|
    t.string     :name
  end

  create_table :projects do |t|
    t.string     :name
  end

  create_table :organizations do |t|
    t.string     :name
  end

  create_table :members do |t|
    t.string :name
  end

  create_table :classrooms do |t|
    t.string :name
  end

  create_table :custom_group_memberships do |t|
    t.references :member, polymorphic: true, index: true
    t.references :group, polymorphic: true, index: true
    t.string     :group_name, index: true
    t.string     :membership_type
  end

  create_table :custom_groups do |t|
    t.string     :name
    t.string     :type
  end

  create_table :custom_users do |t|
    t.string   :name
    t.string   :type
  end

  create_table :project_members do |t|
    t.string :name
  end

  create_table :parents do |t|
    t.string :name
  end

  create_table :students do |t|
    t.string :name
  end

  create_table :enrollments do |t|
    t.references :parent, index: true
    t.references :student, index: true
    t.references :university, index: true
  end
end
