require 'spec_helper'
require 'active_record'

# Load database config
if JRUBY
  require 'jdbc/sqlite3'
  require 'active_record'
  require 'active_record/connection_adapters/jdbcsqlite3_adapter'
else
  require 'sqlite3'
end

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner[:active_record].strategy = :transaction
  end

  config.before(:each) do
    DatabaseCleaner[:active_record].start
  end

  config.after(:each) do
    DatabaseCleaner[:active_record].clean
  end
end

ActiveRecord::Base.establish_connection( :adapter => 'sqlite3', :database => ":memory:" )

ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define(:version => 1) do

  create_table :groups do |t|
    t.string     :name
    t.string     :type
  end
  
  create_table :group_memberships do |t|
    t.string     :member_type
    t.integer    :member_id
    t.integer    :group_id
    t.string     :group_name
  end

  create_table :users do |t|
    t.string   :name
  end

  create_table :widgets do |t|
    t.string     :name
  end

  create_table :organizations do |t|
    t.string     :name
  end
end

require 'groupify'
require 'groupify/adapter/active_record'

class User < ActiveRecord::Base  
  acts_as_group_member
  acts_as_named_group_member
end

class Widget < ActiveRecord::Base
  acts_as_group_member
end

class Group < ActiveRecord::Base  
  acts_as_group :members => [:users, :widgets], :default_members => :users
end

class Organization < Group
end

class GroupMembership < ActiveRecord::Base  
  acts_as_group_membership
end

describe Group do
  it { should respond_to :members}
  it { should respond_to :add }
end

describe User do
  it { should respond_to :groups}
  it { should respond_to :in_group?}
  it { should respond_to :in_any_group?}
  it { should respond_to :in_all_groups?}
  it { should respond_to :shares_any_group?}
end

describe "Group Member" do
  let(:user) { User.create }
  let(:group) { Group.create }
  
  it "can have a group added to it" do
    user.groups << group
    user.groups.should include(group)
    group.members.should include(user)
    group.users.should include(user)
  end
  
  it "can be added to a group" do
    group.add user
    user.groups.should include(group)
    group.members.should include(user)
  end
  
  it "can be found by group" do
    group.add user
    
    User.in_group(group).first.should eql(user)
  end

  it "can find the group it belongs to" do
    group.add user
    
    Group.with_member(user).first.should == group
  end

  it "can belong to many groups" do
    user.groups << group
    group2 = Group.create
    user.groups << group2
    
    user.groups.should include(group)
    user.groups.should include(group2)
    
    User.in_group(group).first.should eql(user)
    User.in_group(group2).first.should eql(user)
    
    User.in_any_group(group).first.should eql(user)
    User.in_all_groups(group, group2).first.should eql(user)
    User.in_all_groups([group, group2]).first.should eql(user)
  end
  
  it "can have named groups" do
    user.named_groups << :admin
    user.named_groups << :user
    user.save
    user.named_groups.should include(:admin)
    
    user.in_named_group?(:admin).should be_true
    user.in_any_named_group?(:admin, :user, :test).should be_true
    user.in_all_named_groups?(:admin, :user).should be_true
    user.in_all_named_groups?(:admin, :user, :test).should be_false

    User.in_named_group(:admin).first.should eql(user)
    User.in_any_named_group(:admin, :test).first.should eql(user)
    User.in_all_named_groups(:admin, :user).first.should eql(user)
    
    # Uniqueness
    user.named_groups << :admin
    user.save
    user.named_groups.count{|g| g == :admin}.should == 1
  end
  
  it "can check if groups are shared" do
    user.groups << group
    user2 = User.create(:groups => [group])
    
    user.shares_any_group?(user2).should be_true
    User.shares_any_group(user).to_a.should include(user2)
  end
  
  it "can check if named groups are shared" do
    user.named_groups << :admin
    user2 = User.create(:named_groups => [:admin])
    
    user.shares_any_named_group?(user2).should be_true
    User.shares_any_named_group(user).to_a.should include(user2)
  end
end