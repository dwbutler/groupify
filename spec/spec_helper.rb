require 'rubygems'
require 'bundler/setup'

Bundler.require(:default, :test, :development)

JRUBY = defined?(JRUBY_VERSION)

RSpec.configure do |config|
  config.order = "random"
end