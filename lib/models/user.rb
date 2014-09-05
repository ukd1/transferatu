module Transferatu
  class User < Sequel::Model
    include Transferatu::Loggable
    include BCrypt

    plugin :timestamps
    plugin :paranoid

    one_to_many :groups

    attr_secure :callback_password, :secret => Config.at_rest_fernet_secret

    def password
      @password ||= Password.new(password_hash)
    end

    def password=(new_password)
      @password = Password.create(new_password)
      self.password_hash = @password
    end
  end
end
