require 'groupify'
require 'rails'

module Groupify
  class Railtie < Rails::Railtie

    initializer "groupify.active_record" do |app|
      ActiveSupport.on_load :active_record do
        require 'groupify/adapter/active_record'
      end
    end
    
    initializer "groupify.mongoid" do |app|
      if defined?(Mongoid)
        require 'groupify/adapter/mongoid'
      end
    end
    
  end
end
