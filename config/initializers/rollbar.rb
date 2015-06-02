Rollbar.configure do |config|
  config.access_token = ENV["ROLLBAR_ACCESS_TOKEN"]
  config.environment = ENV['ROLLBAR_ENV'] || 'staging'
  config.use_sucker_punch
end

