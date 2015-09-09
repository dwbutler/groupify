class AddGroupTypeToGroupMemberships < ActiveRecord::Migration
  def change
    add_column :group_memberships, :group_type, :string
    GroupMembership.reset_column_information
    GroupMembership.update_all(group_type: 'Group')
  end
end
