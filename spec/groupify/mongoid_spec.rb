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