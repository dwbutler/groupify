require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

require 'active_support'
require 'active_support/all'
require 'rails'
require 'active_record'

# Load mongoid config
if Mongoid::VERSION < '3'
  ENV["MONGOID_ENV"] = "test"
  Mongoid.load!('./spec/mongoid2.yml')
else
  Mongoid.load!('./spec/mongoid3.yml', :test)
end
#Mongoid.logger.level = :info