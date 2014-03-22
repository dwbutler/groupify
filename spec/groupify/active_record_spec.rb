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
    t.string   :type
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

class Manager < User
end

class Widget < ActiveRecord::Base
  acts_as_group_member
end

class Group < ActiveRecord::Base  
  acts_as_group :members => [:users, :widgets], :default_members => :users
end

class Organization < Group
  has_members :managers
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

ActiveRecord::Base.logger = Logger.new(STDOUT)

describe Groupify::ActiveRecord do
  let(:user) { User.create! }
  let(:group) { Group.create! }
  let(:widget) { Widget.create! }
  
  it "adds a group to a member" do
    user.groups << group
    user.groups.should include(group)
    group.members.should include(user)
    group.users.should include(user)
  end
  
  it "adds a member to a group" do
    group.add user
    user.groups.should include(group)
    group.members.should include(user)
  end

  it 'lists which member classes can belong to this group' do
    group.class.member_classes.should include(User, Widget)
    group.member_classes.should include(User, Widget)
    
    Organization.member_classes.should include(User, Widget, Manager)
  end
  
  it "finds members by group" do
    group.add user
    
    User.in_group(group).first.should eql(user)
  end

  it "finds the group a member belongs to" do
    group.add user
    
    Group.with_member(user).first.should == group
  end

  it "removes the membership relation when a member is destroyed" do
    group.add user
    user.destroy
    group.should_not be_destroyed
    group.users.should_not include(user)
  end

  it "removes the membership relations when a group is destroyed" do
    group.add user
    group.add widget
    group.destroy

    user.should_not be_destroyed
    user.reload.groups.should be_empty

    widget.should_not be_destroyed
    widget.reload.groups.should be_empty
  end

  context 'when merging' do
    let(:task) { Task.create! }
    let(:manager) { Manager.create! }

    it "moves the members from source to destination and destroys the source" do
      source = Group.create!
      destination = Organization.create!

      source.add(user)
      destination.add(manager)

      destination.merge!(source)
      source.destroyed?.should be_true
      
      destination.users.should include(user, manager)
      destination.managers.should include(manager)
    end

    it "fails to merge if the destination group cannot contain the source group's members" do
      source = Organization.create!
      destination = Group.create!

      source.add(manager)
      destination.add(user)

      # Managers cannot be members of a Group
      expect {destination.merge!(source)}.to raise_error(ArgumentError)
    end

    it "merges incompatible groups as long as all the source members can be moved to the destination" do
      source = Organization.create!
      destination = Group.create!

      source.add(user)
      destination.add(widget)

      expect {destination.merge!(source)}.to_not raise_error

      source.destroyed?.should be_true
      destination.users.to_a.should include(user)
      destination.widgets.to_a.should include(widget)
    end
  end

  it "members can belong to many groups" do
    user.groups << group
    group2 = Group.create!
    user.groups << group2
    
    user.groups.should include(group)
    user.groups.should include(group2)
    
    User.in_group(group).first.should eql(user)
    User.in_group(group2).first.should eql(user)
    
    User.in_any_group(group).first.should eql(user)
    User.in_all_groups(group, group2).first.should eql(user)
    User.in_all_groups([group, group2]).first.should eql(user)
  end
  
  it "members can have named groups" do
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
  
  it "members can check if groups are shared" do
    user.groups << group
    widget.groups << group
    user2 = User.create!(:groups => [group])
    
    user.shares_any_group?(widget).should be_true
    Widget.shares_any_group(user).to_a.should include(widget)
    User.shares_any_group(widget).to_a.should include(user, user2)

    user.shares_any_group?(user2).should be_true
    User.shares_any_group(user).to_a.should include(user2)
  end
  
  it "members can check if named groups are shared" do
    user.named_groups << :admin
    user2 = User.create!(:named_groups => [:admin])
    
    user.shares_any_named_group?(user2).should be_true
    User.shares_any_named_group(user).to_a.should include(user2)
  end
end