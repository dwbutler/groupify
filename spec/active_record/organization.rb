class Organization < Group
  groupify :group_member

  has_members :managers, :organizations
end
