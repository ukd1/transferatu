module Transferatu
  module Endpoints
    # The base class for all Sinatra-based endpoints. Use sparingly.
    class Base < Sinatra::Base
      register Pliny::Extensions::Instruments
      register Sinatra::Namespace

      helpers Pliny::Helpers::Params

      set :dump_errors, false
      set :raise_errors, true
      set :show_exceptions, false

      error Pliny::Errors::Error do
        Pliny::Errors::Error.render(env["sinatra.error"])
      end

      configure :development do
        register Sinatra::Reloader
      end

      not_found do
        content_type :json
        status 404
        "{}"
      end

      use Committee::Middleware::RequestValidation,
        schema: JSON.parse(File.read("docs/schema.json")),
        strict: false

      helpers do
        def data
          env["committee.params"]
        end

        def respond(response, status: nil)
          status(status) unless status.nil?
          JSON.generate(response)
        end

        def current_user
          Transferatu::RequestStore.current_user
        end
      end
    end
  end
end
