source "https://rubygems.org"
ruby "2.2.0"

gem "multi_json"
gem "oj"
gem "pg"
gem "pliny"
gem "pry"
gem "pry-doc"
gem "puma"
gem "rack-ssl"
gem "rake"
gem "rollbar"
gem "sequel"
gem "sequel-paranoid"
gem "sequel_pg", require: "sequel"
gem "sinatra", require: "sinatra/base"
gem "sinatra-contrib", require: ["sinatra/namespace", "sinatra/reloader"]
gem "sinatra-router"
gem "sucker_punch"

# additional gems (not from template)
gem "attr_secure", git: "https://github.com/deafbybeheading/attr_secure", branch: 'fernet-2.0-support-empty-values'
gem "aws-sdk-core"
gem "bcrypt"
gem "clockwork"
gem "committee" # promoted from 'test' in template
gem "fernet"
gem "lpxc"
gem "pgversion"
gem "platform-api"
gem "rest-client"

group :development, :test do
  gem "pry-byebug"
end

group :development do
  gem "foreman"
end

group :test do
  gem "database_cleaner"
  gem "factory_girl", "~> 4.0"
  gem "rack-test"
  gem "rspec"
end
