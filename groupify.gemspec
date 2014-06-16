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
  gem.license       = 'MIT'

  gem.add_development_dependency "mongoid", ">= 3.1"
  gem.add_development_dependency "activerecord", ">= 3.2"

  unless defined?(JRUBY_VERSION)
    gem.add_development_dependency "sqlite3"
  end
  
  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec", ">= 3"

  gem.add_development_dependency "database_cleaner"
  gem.add_development_dependency "appraisal"
end
