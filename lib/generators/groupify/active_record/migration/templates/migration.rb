class GroupifyMigration < ActiveRecord::Migration
  def change
    create_table :groups do |t|
      t.string     :type
    end

    create_table :group_memberships do |t|
      t.references :member, polymorphic: true, index: true
      t.references :group, polymorphic: true, index: true

      # The named group to which a member belongs (if using)
      t.string     :group_name, index: true

      # The type of membership the member belongs with
      t.string     :membership_type
    end
  end
end
