require 'rubygems'
require 'bundler/setup'

Bundler.require(:default, :test, :development)

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