require 'rubygems'
require 'bundler/setup'

Bundler.require(:default, :test, :development)

# Load mongoid config
if Mongoid::VERSION < '3'
  ENV["MONGOID_ENV"] = "test"
  Mongoid.load!('./spec/mongoid2.yml')
  Mongoid.logger.level = :info
else
  Mongoid.load!('./spec/mongoid3.yml', :test)
end

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