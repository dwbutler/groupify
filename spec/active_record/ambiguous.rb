class Ambiguous < ActiveRecord::Base
  self.table_name = 'groups'
  
  groupify :group, member_class_name: 'Ambiguous'
  groupify :group_member, group_class_name: 'Ambiguous'
end
