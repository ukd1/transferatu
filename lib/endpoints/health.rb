module Transferatu::Middleware
  class Health
    def initialize(app)
      @app = app
    end

    def call(env)
      if env["PATH_INFO"] =~ %r{\A/health\z}
        unless healthy?
          # TODO: log more details--we probably don't want to expose
          # too much in the unprotected health check endpoint, but
          # it'd be nice to know what's going wrong, especially if the
          # health check gets more elaborate.
          [503, {"Content-Type" => "application/json; charset=utf-8"},
           [JSON.generate(message: "health check failed")]]
        else
          [200, {"Content-Type" => "application/json; charset=utf-8"},
           [JSON.generate(message: "everything is copacetic")]]
        end
      else
        @app.call(env)
      end
    end

    private

    def healthy?
      # TODO: restore actual check
      true
    end
  end
end
