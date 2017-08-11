source 'https://rubygems.org'

group :development do
  gem 'pry'
  gem "github_changelog_generator"
end

group :test do
  gem "rspec", ">= 3"

  gem "database_cleaner", ">= 1.5.3"
  gem "combustion", ">= 0.5.5"
  #gem "appraisal"
  gem 'coveralls', require: false
  gem "codeclimate-test-reporter", require: nil
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
  gem "mysql2", ">= 0.3.11"
  gem "pg"
end
