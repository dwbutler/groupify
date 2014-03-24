require 'spec_helper'

RSpec.configure do |config|
  config.order = "random"
  
  config.before(:suite) do
    DatabaseCleaner[:mongoid].strategy = :truncation
  end

  config.before(:each) do
    DatabaseCleaner[:mongoid].start
  end

  config.after(:each) do
    DatabaseCleaner[:mongoid].clean
  end
end

require 'mongoid'
puts "Mongoid version #{Mongoid::VERSION}"

require 'mongoid-rspec'
include Mongoid::Matchers

# Load mongoid config
Mongoid.load!('./spec/groupify/mongoid.yml', :test)
#Moped.logger = Logger.new(STDOUT)

require 'groupify'
require 'groupify/adapter/mongoid'

class MongoidUser
  include Mongoid::Document
  
  acts_as_group_member :class_name => 'MongoidGroup'
  acts_as_named_group_member
end

class MongoidTask
  include Mongoid::Document
  
  acts_as_group_member :class_name => 'MongoidGroup'
end

class MongoidIssue
  include Mongoid::Document

  acts_as_group_member :class_name => 'MongoidProject'
end

class MongoidGroup
  include Mongoid::Document
  
  acts_as_group :members => [:mongoid_users, :mongoid_tasks], :default_members => :mongoid_users
  alias_method :users, :mongoid_users
  alias_method :tasks, :mongoid_tasks
end

class MongoidProject < MongoidGroup
  has_members :mongoid_issues
  alias_method :issues, :mongoid_issues
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

describe Groupify::Mongoid do
  let!(:user) { MongoidUser.create! }
  let!(:group) { MongoidGroup.create! }
  let(:task) { MongoidTask.create! }
  let(:issue) { MongoidIssue.create! }
  
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
    group.class.member_classes.should include(MongoidUser, MongoidTask)
    group.member_classes.should include(MongoidUser, MongoidTask)

    MongoidProject.member_classes.should include(MongoidUser, MongoidTask, MongoidIssue)
  end
  
  it "finds members by group" do
    group.add user
    
    MongoidUser.in_group(group).first.should eql(user)
  end

  it "finds the groups a member belongs to" do
    group.add user
    
    MongoidGroup.with_member(user).first.should == group
  end

  it "removes the membership relation when a member is destroyed" do
    group.add user
    user.destroy
    group.should_not be_destroyed
    group.users.should_not include(user)
  end

  it "removes the membership relations when a group is destroyed" do
    group.add user
    group.add task
    group.destroy

    user.should_not be_destroyed
    user.reload.groups.should be_empty

    task.should_not be_destroyed
    task.reload.groups.should be_empty
  end

  context 'when merging' do
    it "moves the members from source to destination and destroys the source" do
      source = MongoidGroup.create!
      destination = MongoidProject.create!

      source.add(user)
      destination.add(task)

      destination.merge!(source)
      source.destroyed?.should be_true
      
      destination.users.to_a.should include(user)
      destination.tasks.to_a.should include(task)
    end

    it "fails to merge if the destination group cannot contain the source group's members" do
      source = MongoidProject.create!
      destination = MongoidGroup.create!

      source.add(issue)
      destination.add(user)

      # Issues cannot be members of a MongoidGroup
      expect {destination.merge!(source)}.to raise_error(ArgumentError)
    end

    it "merges incompatible groups as long as all the source members can be moved to the destination" do
      source = MongoidProject.create!
      destination = MongoidGroup.create!

      source.add(user)
      destination.add(task)

      expect {destination.merge!(source)}.to_not raise_error

      source.destroyed?.should be_true
      destination.users.to_a.should include(user)
      destination.tasks.to_a.should include(task)
    end
  end

  it "members can belong to many groups" do
    user.groups << group
    group2 = MongoidGroup.create!
    user.groups << group2
    
    user.groups.should include(group)
    user.groups.should include(group2)
    
    MongoidUser.in_group(group).first.should eql(user)
    MongoidUser.in_group(group2).first.should eql(user)
    
    MongoidUser.in_any_group(group).first.should eql(user)
    MongoidUser.in_all_groups(group, group2).first.should eql(user)
    MongoidUser.in_all_groups([group, group2]).first.should eql(user)
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

    MongoidUser.in_named_group(:admin).first.should eql(user)
    MongoidUser.in_any_named_group(:admin, :test).first.should eql(user)
    MongoidUser.in_all_named_groups(:admin, :user).first.should eql(user)
    
    # Uniqueness
    user.named_groups << :admin
    user.save
    user.named_groups.count{|g| g == :admin}.should == 1
  end
  
  it "members can check if groups are shared" do
    user.groups << group
    user2 = MongoidUser.create!(:groups => [group])
    
    user.shares_any_group?(user2).should be_true
    MongoidUser.shares_any_group(user).to_a.should include(user2)
  end
  
  it "members can check if named groups are shared" do
    user.named_groups << :admin
    user2 = MongoidUser.create!(:named_groups => [:admin])
    
    user.shares_any_named_group?(user2).should be_true
    MongoidUser.shares_any_named_group(user).to_a.should include(user2)
  end
end