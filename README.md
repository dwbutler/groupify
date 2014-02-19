# Groupify [![Build Status](https://secure.travis-ci.org/dwbutler/groupify.png)](http://travis-ci.org/dwbutler/groupify) [![Dependency Status](https://gemnasium.com/dwbutler/groupify.png)](https://gemnasium.com/dwbutler/groupify) [![Code Climate](https://codeclimate.com/github/dwbutler/groupify.png)](https://codeclimate.com/github/dwbutler/groupify)

Adds group and membership functionality to Rails models.

The following ORMs are supported:
Mongoid 3.1 & 4.0, ActiveRecord 3.2 & 4.x

The following Rubies are supported:
Ruby 1.9.3, 2.0.0, 2.1.0 (MRI, REE, JRuby, and Rubinius).

## Installation

Add this line to your application's Gemfile:

    gem 'groupify'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install groupify

## Getting Started

### Active Record
Add a migration similar to the following:

```ruby
class CreateGroups < ActiveRecord::Migration
  def change
    create_table :groups do |t|
      t.string     :type      # Only needed if using single table inheritence
    end
    
    create_table :group_memberships do |t|
      t.string     :member_type   # Needed to make polymorphic members work
      t.integer    :member_id   # The member that belongs to this group
      t.integer    :group_id    # The group to which the member belongs
      t.string     :group_name    # Links a member to a named group (if using named groups)
    end

    add_index :group_memberships, [:member_id, :member_type]
    add_index :group_memberships, :group_id
    add_index :group_memberships, :group_name
  end
end
```

In your group model:

```ruby
class Group < ActiveRecord::Base  
  acts_as_group :members => [:users, :assignments], :default_members => :users
end
```

In your member models (i.e. `User`):

```ruby
class User < ActiveRecord::Base
  acts_as_group_member
  acts_as_named_group_member
end

class Assignment < ActiveRecord::Base
  acts_as_group_member
end
```

### Mongoid
In your group model:

```ruby
class Group
  include Mongoid::Document

  acts_as_group :members => [:users], :default_members => :users
end
```

In your member models (i.e. `User`):

```ruby
class User
  include Mongoid::Document
  
  acts_as_group_member
  acts_as_named_group_member
end
```

## Basic Usage

Create groups and add members:

```ruby
group = Group.new
user = User.new

user.groups << group
# or
group.add user

user.in_group?(group)
# => true
```

Add to named groups:

```ruby
user.named_groups << :admin
user.in_named_group?(:admin)
# => true
```

Check if two members share any of the same groups:

```ruby
user1.shares_any_group?(user2)
user2.shares_any_named_group?(user1)
```

Query for groups & members:

```ruby
User.in_group(group)         # Find all users in this group
User.in_named_group(:admin)  # Find all users in this named group
Group.with_member(user)      # Find all groups with this user

User.shares_any_group(user)       # Find all users that share any groups with this user
User.shares_any_named_group(user) # Find all users that share any named groups with this user
```

Merge one group into another:

```ruby
# Moves the members of source into destination, and destroys source
destination_group.merge!(source_group)
```

Check the specs for more details.

## Using for Authorization
Groupify was originally created to help implement user authorization, although it can be used
generically for much more than that. Here is how to do it.

### With CanCan

```ruby
class Ability
  include CanCan::Ability

  def initialize(user)
    …
    # Implements group authorization
    # Users can only manage assignment which belong to the same group
    can [:manage], Assignment, Assignment.shares_any_group(user) do |assignment|
      assignment.shares_any_group?(user)
    end
  end
end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
