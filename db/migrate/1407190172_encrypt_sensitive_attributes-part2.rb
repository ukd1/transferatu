require "bundler"
Bundler.require

require './lib/initializer'

Sequel.migration do
  up do
    Transferatu::Transfer.all.each do |xfer|
      xfer.from_url = xfer.unencrypted_from_url
      xfer.to_url = xfer.unencrypted_to_url
      xfer.save
    end
    Transferatu::User.all.each do |user|
      user.token = user.unencrypted_token
      user.save
    end
    Transferatu::Group.all.each do |group|
      group.log_input_url = group.unencrypted_log_input_url
      group.save
    end
  end

  down do
    raise Sequel::Error, 'irreversible migration'
  end
end
