module Transferatu::Endpoints
  module Authenticator
    attr_reader :current_user

    def authenticate
      # TODO: this authentication check is pretty crufty
      auth = Rack::Auth::Basic::Request.new(request.env)
      unless auth.provided? && auth.basic? && auth.credentials
        throw(:halt, [401, "Not Authorized\n"])
      end
      user, token = auth.credentials
      @current_user = Transferatu::User.where(name: user, token: token, deleted_at: nil).first
      unless @current_user
        throw(:halt, [401, "Not Authorized\n"])
      end
    end
  end
end
