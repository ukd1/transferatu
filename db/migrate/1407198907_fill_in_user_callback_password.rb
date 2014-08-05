require "bundler"
Bundler.require

require './lib/initializer'
Sequel.migration do
  up do
    Transferatu::User.all.each do |user|
      user.callback_password = password = SecureRandom.base64(128)
      user.save
    end
  end

  down do
    raise Sequel::Error, 'irreversible migration'
  end
end
