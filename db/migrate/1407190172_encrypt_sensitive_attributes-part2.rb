require './config/config'
require 'fernet'

def encrypt(message)
  if message.nil? || message.empty?
    message
  else
    Fernet.generate(Config.at_rest_fernet_secret, message)
  end
end

Sequel.migration do
  up do
    self[:transfers].each do |xfer|
      unencrypted_from_url = xfer[:unencrypted_from_url]
      unencrypted_to_url = xfer[:unencrypted_to_url]
      self[:transfers].where(uuid: xfer[:uuid])
        .update(from_url: encrypt(unencrypted_from_url),
                to_url: encrypt(unencrypted_to_url))
    end
    self[:users].each do |user|
      unencrypted_token = user[:unencrypted_token]
      self[:users].where(uuid: user[:uuid])
        .update(token: encrypt(unencrypted_token))
    end
    self[:groups].each do |group|
      unencrypted_log_input_url = group[:unencrypted_log_input_url]
      self[:groups].where(uuid: group[:uuid])
        .update(log_input_url: encrypt(unencrypted_log_input_url))
    end
  end

  down do
    raise Sequel::Error, 'irreversible migration'
  end
end
