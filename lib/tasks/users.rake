namespace :users do
  task :create, :name do |t, args|
    require "bundler"
    Bundler.require
    require_relative "../initializer"

    password=` dd if=/dev/urandom bs=32 count=1 2>/dev/null | openssl base64`
    if password.empty?
      raise StandardError, "Could not generate password"
    end
    token=` dd if=/dev/urandom bs=32 count=1 2>/dev/null | openssl base64`
    if token.empty?
      raise StandardError, "Could not generate token"
    end
    Transferatu::User.create(name: args.name, password: password, token: token)
    puts "Created user #{args.name} with password #{password}"
  end
end
