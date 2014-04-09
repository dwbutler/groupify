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

class MongoidManager < MongoidUser
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
  has_members :mongoid_managers
  alias_method :issues, :mongoid_issues
  alias_method :managers, :mongoid_managers
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
  let(:manager) { MongoidManager.create! }

  it "members and groups are empty when initialized" do
    expect(user.groups).to be_empty
    expect(MongoidUser.new.groups).to be_empty

    expect(MongoidGroup.new.members).to be_empty
    expect(group.members).to be_empty
  end
  
  it "adds a group to a member" do
    user.groups << group
    expect(user.groups).to include(group)
    expect(group.members).to include(user)
    expect(group.users).to include(user)
  end
  
  it "adds a member to a group" do
    group.add user
    expect(user.groups).to include(group)
    expect(group.members).to include(user)
  end

  it "adds multiple members to a group" do
    group.add(user, task)
    expect(group.users).to include(user)
    expect(group.tasks).to include(task)

    users = [MongoidUser.create!, MongoidUser.create!]
    group.add(users)
    expect(group.users).to include(*users)
  end

  it 'lists which member classes can belong to this group' do
    expect(group.class.member_classes).to include(MongoidUser, MongoidTask)
    expect(group.member_classes).to include(MongoidUser, MongoidTask)

    expect(MongoidProject.member_classes).to include(MongoidUser, MongoidTask, MongoidIssue)
  end
  
  it "finds members by group" do
    group.add user
    
    expect(MongoidUser.in_group(group).first).to eql(user)
  end

  it "finds the groups a member belongs to" do
    group.add user
    
    expect(MongoidGroup.with_member(user).first).to eq(group)
  end

  it "removes the membership relation when a member is destroyed" do
    group.add user
    user.destroy
    expect(group).not_to be_destroyed
    expect(group.users).not_to include(user)
  end

  it "removes the membership relations when a group is destroyed" do
    group.add user
    group.add task
    group.destroy

    expect(user).not_to be_destroyed
    expect(user.reload.groups).to be_empty

    expect(task).not_to be_destroyed
    expect(task.reload.groups).to be_empty
  end

  context 'when merging' do
    it "moves the members from source to destination and destroys the source" do
      source = MongoidGroup.create!
      destination = MongoidProject.create!

      source.add(user)
      source.add(manager)
      destination.add(task)

      destination.merge!(source)
      expect(source.destroyed?).to be_true
      
      expect(destination.users.to_a).to include(user)
      expect(destination.managers.to_a).to include(manager)
      expect(destination.tasks.to_a).to include(task)
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

      expect(source.destroyed?).to be_true
      expect(destination.users.to_a).to include(user)
      expect(destination.tasks.to_a).to include(task)
    end
  end

  it "members can belong to many groups" do
    user.groups << group
    group2 = MongoidGroup.create!
    user.groups << group2

    group3 = user.groups.create!

    user.save!

    group4 = MongoidGroup.create!
    
    expect(user.groups).to include(group, group2, group3)

    expect(MongoidUser.in_group(group).first).to eql(user)
    expect(MongoidUser.in_group(group2).first).to eql(user)
    expect(user.in_group?(group)).to be_true
    expect(user.in_group?(group4)).to be_false
    
    expect(MongoidUser.in_any_group(group, group4).first).to eql(user)
    expect(MongoidUser.in_any_group(group4)).to be_empty
    expect(user.in_any_group?(group2, group4)).to be_true
    expect(user.in_any_group?(group4)).to be_false

    expect(MongoidUser.in_all_groups(group, group2).first).to eql(user)
    expect(MongoidUser.in_all_groups([group, group3]).first).to eql(user)
    expect(MongoidUser.in_all_groups([group2, group4])).to be_empty
    expect(user.in_all_groups?(group, group3)).to be_true
    expect(user.in_all_groups?(group, group4)).to be_false

    expect(MongoidUser.in_only_groups(group, group2, group3).first).to eql(user)
    expect(MongoidUser.in_only_groups(group, group2, group3, group4)).to be_empty
    expect(MongoidUser.in_only_groups(group, group2)).to be_empty
    expect(user.in_only_groups?(group, group2, group3)).to be_true
    expect(user.in_only_groups?(group, group2)).to be_false
    expect(user.in_only_groups?(group, group2, group3, group4)).to be_false
  end
  
  it "members can have named groups" do
    user.named_groups << :admin
    user.named_groups.concat [:user, :poster]
    user.save!
    expect(user.named_groups).to include(:admin)
    
    expect(user.in_named_group?(:admin)).to be_true
    expect(user.in_any_named_group?(:admin, :user, :test)).to be_true
    expect(user.in_all_named_groups?(:admin, :user)).to be_true
    expect(user.in_all_named_groups?(:admin, :user, :test)).to be_false

    expect(user.in_only_named_groups?(:admin, :user, :poster)).to be_true
    expect(user.in_only_named_groups?(:admin, :user)).to be_false
    expect(user.in_only_named_groups?(:admin, :user, :foo)).to be_false

    expect(MongoidUser.in_named_group(:admin).first).to eql(user)
    expect(MongoidUser.in_any_named_group(:admin, :test).first).to eql(user)
    expect(MongoidUser.in_all_named_groups(:admin, :user).first).to eql(user)
    expect(MongoidUser.in_only_named_groups(:admin, :user, :poster).first).to eql(user)
    
    # Uniqueness
    user.named_groups << :admin
    user.save!
    expect(user.named_groups.count{|g| g == :admin}).to eq(1)
  end
  
  it "members can check if groups are shared" do
    user.groups << group
    user2 = MongoidUser.create!(:groups => [group])
    
    expect(user.shares_any_group?(user2)).to be_true
    expect(MongoidUser.shares_any_group(user).to_a).to include(user2)
  end
  
  it "members can check if named groups are shared" do
    user.named_groups << :admin
    user2 = MongoidUser.create!(:named_groups => [:admin])
    
    expect(user.shares_any_named_group?(user2)).to be_true
    expect(MongoidUser.shares_any_named_group(user).to_a).to include(user2)
  end
end