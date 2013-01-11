require 'spec_helper'
require 'mongoid'
require 'mongoid-rspec'
include Mongoid::Matchers

# Load mongoid config
if Mongoid::VERSION < '3'
  ENV["MONGOID_ENV"] = "test"
  Mongoid.load!('./spec/groupify/mongoid2.yml')
  Mongoid.logger.level = Logger::INFO
else
  Mongoid.load!('./spec/groupify/mongoid3.yml', :test)
end

require 'groupify'

class MongoidUser
  include Mongoid::Document
  
  acts_as_group_member :class_name => 'MongoidGroup'
  acts_as_named_group_member
end

class MongoidTask
  include Mongoid::Document
  
  acts_as_group_member :class_name => 'MongoidGroup'
end

class MongoidGroup
  include Mongoid::Document
  
  acts_as_group :members => [:mongoid_users, :mongoid_tasks], :default_members => :mongoid_users
  alias_method :users, :mongoid_users
end

class MongoidProject < MongoidGroup
  
  alias_method :tasks, :mongoid_tasks
end

describe MongoidGroup do
  it { should respond_to :members}
  it { should respond_to :add }
end

describe MongoidUser do
  it { should respond_to :groups}
  it { should respond_to :in_group?}
  it { should respond_to :in_any_group?}
  it { should respond_to :in_all_groups?}
  it { should respond_to :shares_any_group?}
  
  # Mongoid specific
  it { should have_and_belong_to_many(:groups).of_type(MongoidGroup) }
end

describe "Mongoid Model" do
  let!(:user) { MongoidUser.create }
  let!(:group) { MongoidGroup.create }
  
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
    
    MongoidUser.in_group(group).first.should eql(user)
  end

  it "can find the group it belongs to" do
    group.add user
    
    MongoidGroup.with_member(user).first.should == group
  end

  it "can belong to many groups" do
    user.groups << group
    group2 = MongoidGroup.create
    user.groups << group2
    
    user.groups.should include(group)
    user.groups.should include(group2)
    
    MongoidUser.in_group(group).first.should eql(user)
    MongoidUser.in_group(group2).first.should eql(user)
    
    MongoidUser.in_any_group(group).first.should eql(user)
    MongoidUser.in_all_groups(group, group2).first.should eql(user)
    MongoidUser.in_all_groups([group, group2]).first.should eql(user)
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

    MongoidUser.in_named_group(:admin).first.should eql(user)
    MongoidUser.in_any_named_group(:admin, :test).first.should eql(user)
    MongoidUser.in_all_named_groups(:admin, :user).first.should eql(user)
    
    # Uniqueness
    user.named_groups << :admin
    user.save
    user.named_groups.count{|g| g == :admin}.should == 1
  end
  
  it "can check if groups are shared" do
    user.groups << group
    user2 = MongoidUser.create(:groups => [group])
    
    user.shares_any_group?(user2).should be_true
    MongoidUser.shares_any_group(user).to_a.should include(user2)
  end
  
  it "can check if named groups are shared" do
    user.named_groups << :admin
    user2 = MongoidUser.create(:named_groups => [:admin])
    
    user.shares_any_named_group?(user2).should be_true
    MongoidUser.shares_any_named_group(user).to_a.should include(user2)
  end
end