source 'https://rubygems.org'

# Specify your gem's dependencies in groupify.gemspec
gemspec

platform :jruby do
  gem "jdbc-sqlite3"
  gem "activerecord-jdbcsqlite3-adapter"
  
  if defined?(RUBY_VERSION) && RUBY_VERSION < '1.9'
    gem "json"
  end
end

