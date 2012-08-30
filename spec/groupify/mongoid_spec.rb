require 'spec_helper'
require 'mongoid'
require 'mongoid-rspec'
include Mongoid::Matchers

class MongoidUser
  include Mongoid::Document
  
  acts_as_group_member :class_name => 'MongoidGroup'
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

describe "MongoidUser" do
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
end