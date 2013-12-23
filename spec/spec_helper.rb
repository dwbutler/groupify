require 'rubygems'
require 'bundler/setup'

Bundler.require(:default, :test, :development)

JRUBY = defined?(JRUBY_VERSION)

puts "Mongoid version #{Mongoid::VERSION}"
puts "ActiveRecord version #{ActiveSupport::VERSION}"

RSpec.configure do |config|
  config.order = "random"
end
