# Groupify [![Build Status](https://secure.travis-ci.org/dwbutler/groupify.png)](http://travis-ci.org/dwbutler/groupify)
Adds group and membership functionality to Rails models.

Currently only Mongoid is supported. Tested in Ruby 1.8.7 and 1.9.3.

## Installation

Add this line to your application's Gemfile:

    gem 'groupify'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install groupify

## Getting Started
In your group model:

```ruby
class Group
	include Mongoid::Document

	acts_as_group
end
```

In your user model:

```ruby
class User
	include Mongoid::Document
	
	acts_as_group_member
end
```

## Usage

Create groups and add members:

```ruby
group = Group.new
user = User.new

user.groups << group
or
group.add user

user.in_group?(group)	=> true
```

Add to named groups:

```ruby
user.groups << :admin
user.in_group?(:admin)	=> true
```

Query for groups & members:

```ruby
User.in_group(group)	# Find all users in this group
Group.with_member(user)	# Find all groups with this user
```

Check the specs for more details.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
