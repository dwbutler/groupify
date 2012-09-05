# -*- encoding: utf-8 -*-
require File.expand_path('../lib/groupify/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["dwbutler"]
  gem.email         = ["dwbutler@ucla.edu"]
  gem.description   = %q{Adds group and membership functionality to Rails models}
  gem.summary       = %q{Group functionality for Rails}
  gem.homepage      = "https://github.com/dwbutler/groupify"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "groupify"
  gem.require_paths = ["lib"]
  gem.version       = Groupify::VERSION
  
  gem.add_development_dependency "rails", "~> 3.2"
  gem.add_development_dependency "rspec"
  
  if RUBY_VERSION < '1.9'
    gem.add_development_dependency "mongoid", "~> 2.0"
    gem.add_development_dependency 'mongoid-rspec', '1.4.5'
  else
    gem.add_development_dependency "mongoid", "~> 3.0"
    gem.add_development_dependency 'mongoid-rspec', '~> 1.5.1'
  end
  gem.add_development_dependency 'database_cleaner'
end
