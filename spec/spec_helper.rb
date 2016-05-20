require 'bundler/setup'

require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
])
SimpleCov.start

require 'active_support'
require 'active_support/deprecation'
require 'active_support/dependencies/autoload'

Bundler.require(:default, :development)

JRUBY = defined?(JRUBY_VERSION)
DEBUG = ENV['DEBUG']

RSpec.configure do |config|
  config.order = "random"
end
