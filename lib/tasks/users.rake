namespace :users do
  task :create, :name do |t, args|
    require "bundler"
    Bundler.require
    require_relative "../initializer"
    require "securerandom"

    password = SecureRandom.base64(128)
    if password.empty?
      raise StandardError, "Could not generate password"
    end

    callback_password = SecureRandom.base64(128)
    if callback_password.empty?
      raise StandardError, "Could not generate callback password"
    end
    Transferatu::User.create(name: args.name,
                             password: password,
                             callback_password: callback_password)
    puts <<-EOF
Created user #{args.name} with
  password: #{password}
  callback password: #{callback_password}
EOF
  end
end
