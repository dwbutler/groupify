source 'https://rubygems.org'

group :development do
  gem 'pry'
end

group :test do
  gem 'coveralls', require: false
  gem "codeclimate-test-reporter", group: :test, require: nil
end

# Specify your gem's dependencies in groupify.gemspec
gemspec

platforms :jruby do
  gem "activerecord-jdbcsqlite3-adapter"
  gem "activerecord-jdbcmysql-adapter"
  gem "jdbc-mysql"
  gem "activerecord-jdbcpostgresql-adapter"
end

platforms :ruby do
  gem "sqlite3"
  gem "mysql2", "~> 0.3.11"
  gem "pg"
end

if RUBY_VERSION < '2'
  gem 'json', '~> 1.8'
  gem 'tins', '1.6.0', require: false
end
