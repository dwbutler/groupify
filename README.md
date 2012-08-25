# Groupify

Adds group and membership functionality to Rails models.

## Installation

Add this line to your application's Gemfile:

    gem 'groupify'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install groupify

## Getting Started
In your group model:

	class Group
		include Mongoid::Document
		
		acts_as_group
	end

In your user model:

	class User
		include Mongoid::Document
		
		acts_as_group_member
	end

Create groups and add members:

	group = Group.new
	user = User.new
	
	user.groups << group
	or
	group.add user

Check the specs for more details. Currently only Mongoid is supported.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
