module Transferatu::Middleware
  # Authenticates the current user and stores the user object in the
  # given request store, which must define +.current_user=+.
  class Authenticator
    def initialize(app, store:)
      @app = app
      @store = store
    end

    def call(env)
      auth = Rack::Auth::Basic::Request.new(env)
      unless auth.provided? && auth.basic? && auth.credentials
        raise Pliny::Errors::Unauthorized
      end
      user, password = auth.credentials
      candidate_user = Transferatu::User.where(name: user, deleted_at: nil).first
      unless candidate_user && candidate_user.password == password
        raise Pliny::Errors::Unauthorized
      end
      @store.current_user = candidate_user

      @app.call(env)
    end
  end
end
