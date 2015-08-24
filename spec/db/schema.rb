ActiveRecord::Schema.define(version: 0) do
  create_table :groups do |t|
    t.string     :name
    t.string     :type
  end

  create_table :group_memberships do |t|
    t.string     :member_type
    t.integer    :member_id
    t.integer    :group_id
    t.string     :group_name
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
end
