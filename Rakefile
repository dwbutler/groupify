#!/usr/bin/env rake
require "bundler/setup"
require "bundler/gem_tasks"

require 'rspec/core/rake_task'

desc "Run RSpec"
RSpec::Core::RakeTask.new do |t|
  t.verbose = false
end

require 'github_changelog_generator/task'
desc "Regenerate changelog"
GitHubChangelogGenerator::RakeTask.new :changelog do |config|
  config.future_release = '0.7.0'
end

task :default => :spec
