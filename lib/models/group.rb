module Transferatu
  class Group < Sequel::Model
    plugin :timestamps
    plugin :paranoid

    many_to_one :user
    one_to_many :transfers
    one_to_many :schedules

    attr_secure :log_input_url, :secret => Config.at_rest_fernet_secret
  end
end
