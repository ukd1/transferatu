require 'rack/fernet'

Routes = Rack::Builder.new do
  use Pliny::Middleware::RescueErrors, raise: Config.raise_errors?
  use Pliny::Middleware::CORS
  use Pliny::Middleware::RequestID
  use Pliny::Middleware::RequestStore, store: Transferatu::RequestStore
  use Pliny::Middleware::Timeout, timeout: Config.timeout.to_i if Config.timeout.to_i > 0
  use Pliny::Middleware::Versioning,
      default: Config.versioning_default,
      app_name: Config.versioning_app_name if Config.versioning?
  use Rack::Deflater
  use Rack::MethodOverride
  use Rack::SSL if Config.force_ssl?

  use Transferatu::Middleware::Health
  use Transferatu::Middleware::Authenticator, store: Transferatu::RequestStore
  use Rack::Fernet, ->(env) do
    unless Transferatu::RequestStore.current_user.nil?
      Transferatu::RequestStore.current_user.token
    end
  end

  use Pliny::Router do
    mount Transferatu::Endpoints::Transfers
    mount Transferatu::Endpoints::Groups
    mount Transferatu::Endpoints::Schedules
  end

  # root app; but will also handle some defaults like 404
  run Transferatu::Endpoints::Root
end
