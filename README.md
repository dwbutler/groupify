# Groupify
[![Build Status](https://secure.travis-ci.org/dwbutler/groupify.png)](http://travis-ci.org/dwbutler/groupify) [![Coverage Status](https://coveralls.io/repos/dwbutler/groupify/badge.png?branch=master)](https://coveralls.io/r/dwbutler/groupify?branch=master) [![Code Climate](https://codeclimate.com/github/dwbutler/groupify.png)](https://codeclimate.com/github/dwbutler/groupify)

Adds group and membership functionality to Rails models. Defines a polymorphic
relationship between a Group model and any member model. Don't need a Group
model? Use named groups instead to add members to named groups such as
`:admin` or `"Team Rocketpants"`.

The following ORMs are supported:
 * ActiveRecord 3.2, 4.x
 * Mongoid 3.1, 4.0, 

The following Rubies are supported:
 * MRI Ruby 1.9.3, 2.0.x, 2.1.x
 * JRuby (1.9 mode)

## Installation

Add this line to your application's Gemfile:

    gem 'groupify'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install groupify

### Active Record
Add a migration similar to the following:

```ruby
class CreateGroups < ActiveRecord::Migration
  def change
    create_table :groups do |t|
      t.string     :type      # Only needed if using single table inheritance
    end
    
    create_table :group_memberships do |t|
      t.string     :member_type     # Necessary to make polymorphic members work
      t.integer    :member_id       # The id of the member that belongs to this group
      t.integer    :group_id        # The group to which the member belongs
      t.string     :group_name      # The named group to which a member belongs (if using)
      t.string     :membership_type # The type of membership the member belongs with
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
  groupify :group, members: [:users, :assignments], default_members: :users
end
```

In your member models (i.e. `User`):

```ruby
class User < ActiveRecord::Base
  groupify :group_member
  groupify :named_group_member
end

class Assignment < ActiveRecord::Base
  groupify :group_member
end
```

You will also need to define a `GroupMembership` model to join groups to members:

```ruby
class GroupMembership < ActiveRecord::Base  
  groupify :group_membership
end
```

### Mongoid
In your group model:

```ruby
class Group
  include Mongoid::Document

  groupify :group, members: [:users], default_members: :users
end
```

In your member models (i.e. `User`):

```ruby
class User
  include Mongoid::Document
  
  groupify :group_member
  groupify :named_group_member
end
```

## Basic Usage

### Create groups and add members

```ruby
group = Group.new
user = User.new

user.groups << group
# or
group.add user

user.in_group?(group)
# => true

# Add multiple members at once
group.add(user, widget, task)
```

### Add to named groups

```ruby
user.named_groups << :admin
user.in_named_group?(:admin)        # => true
```

### Remove from groups

```ruby
users.groups.destroy(group)          # Destroys this user's group membership for this group
group.users.delete(user)             # Deletes this group's group membership for this user
```

### Check if two members share any of the same groups:

```ruby
user1.shares_any_group?(user2)          # Returns true if user1 and user2 are in any of the same groups
user2.shares_any_named_group?(user1)    # Also works for named groups
```

### Query for groups & members:

```ruby
User.in_group(group)                # Find all users in this group
User.in_named_group(:admin)         # Find all users in this named group
Group.with_member(user)             # Find all groups with this user

User.shares_any_group(user)         # Find all users that share any groups with this user
User.shares_any_named_group(user)   # Find all users that share any named groups with this user
```

### Check if member belongs to any/all groups

```ruby
User.in_any_group(group1, group2)               # Find users that belong to any of these groups
User.in_all_groups(group1, group2)              # Find users that belong to all of these groups
Widget.in_only_groups(group2, group3)           # Find widgets that belong to only these groups

widget.in_any_named_group?(:foo, :bar)          # Check if widget belongs to any of these named groups
user.in_all_named_groups?(:manager, :poster)    # Check if user belongs to all of these named groups
user.in_only_named_groups?(:employee, :worker)  # Check if user belongs to only these named groups
```

### Merge one group into another:

```ruby
# Moves the members of source into destination, and destroys source
destination_group.merge!(source_group)
```

## Membership Types

Membership types allow a member to belong to a group in a more specific way. For example,
you can add a user to a group with membership type of "manager" to specify that this
user has the "manager role" on that group.

This can be used to implement role-based authorization combined with group authorization,
which could be used to mass-assign roles to groups of resources.

It could also be used to add users and resources to the same "sub-group" or "project"
within a larger group (say, an organization).

```ruby
# Add user to group as a specific membership type
group.add(user, as: 'manager')

# Works with named groups too
user.named_groups.add user, as: 'manager'

# Query for the groups that a user belongs to with a certain role
user.groups.as(:manager)
user.named_groups.as('manager')
Group.with_member(user).as('manager')

# Remove a member's membership type from a group
group.users.delete(user, as: 'manager')         # Deletes this group's 'manager' group membership for this user
user.groups.destroy(group, as: 'employee')      # Destroys this user's 'employee' group membership for this group
user.groups.destroy(group)                      # Destroys any membership types this user had in this group

# Find all members that have a certain membership type in a group
User.in_group(group).as(:manager)

# Find all members of a certain membership type regardless of group
User.as(:manager)    # Find users that are managers, we don't care what group

# Check if a member belongs to any/all groups with a certain membership type
user.in_all_groups?(group1, group2, as: 'manager')

# Find all members that share the same group with the same membership type
Widget.shares_any_group(user).as("Moon Launch Project")

# Check is one member belongs to the same group as another member with a certain membership type
user.shares_any_group?(widget, as: 'employee')
```

Note that adding a member to a group with a specific membership type will automatically
add them to that group without a specific membership type. This way you can still query
`groups` and find the member in that group. If you then remove that specific membership
type, they still remain in the group without a specific membership type.

Removing a member from a group will bulk remove any specific membership types as well.

```
group.add(manager, as: 'manager')
manager.groups.include?(group)              # => true

manager.groups.delete(group, as: 'manager')
manager.groups.include?(group)              # => true

group.add(employee, as: 'employee')
employee.groups.delete(group)
employee.in_group?(group)                   # => false
employee.in_group?(group, as: 'employee')   # => false
```

## But wait, there's more!

Check the specs for a complete list of methods and scopes provided by Groupify.

## Using for Authorization
Groupify was originally created to help implement user authorization, although it can be used
generically for much more than that. Here are some examples of how to do it.

### With CanCan

```ruby
class Ability
  include CanCan::Ability

  def initialize(user)
    # Implements group-based authorization
    # Users can only manage assignment which belong to the same group.
    can [:manage], Assignment, Assignment.shares_any_group(user) do |assignment|
      assignment.shares_any_group?(user)
    end
  end
end
```

### With Authority

```ruby
# Whatever class represents a logged-in user in your app
class User
  groupify :named_group_member
  include Authority::UserAbilities
end

class Widget
  groupify :named_group_member
  include Authority::Abilities
end

class WidgetAuthorizer  < ApplicationAuthorizer
  # Implements group-based authorization using named groups.
  # Users can only see widgets which belong to the same named group.
  def readable_by?(user)
    user.shares_any_named_group?(resource)
  end

  # Implements combined role-based and group-based authorization.
  # Widgets can only be updated by users that are employees of the same named group.
  def updateable_by?(user)
    user.shares_any_named_group?(resource, as: :employee)
  end

  # Widgets can only be deleted by users that are managers of the same named group.
  def deletable_by?(user)
    user.shares_any_named_group?(resource, as: :manager)
  end
end

user = User.create!
user.named_groups.add(:team1, as: :employee)

widget = Widget.create!
widget.named_groups << :team1

widget.readable_by?(user) # => true
user.can_update?(widget)  # => true
user.can_delete?(widget)  # => false
```

### With Pundit

```ruby
class PostPolicy < Struct.new(:user, :post)
  # User can only update a published post if they are admin of the same group.
  def update?
    user.shares_any_group?(post, as: :admin) || !post.published?
  end

  class Scope < Struct.new(:user, :scope)
    def resolve
      if user.admin?
        # An admin can see all the posts in the group(s) they are admin for
        scope.shares_any_group(user).as(:admin)
      else
        # Normal users can only see published posts in the same group(s).
        scope.shares_any_group(user).where(published: true)
      end
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
