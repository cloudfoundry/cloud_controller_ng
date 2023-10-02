require 'action_controller/railtie'

class Application < Rails::Application
  config.exceptions_app = routes
  config.middleware.delete ActionDispatch::Session::CookieStore
  config.middleware.delete ActionDispatch::Cookies
  config.middleware.delete ActionDispatch::Flash
  config.middleware.delete ActionDispatch::RequestId
  config.middleware.delete Rails::Rack::Logger
  config.middleware.delete ActionDispatch::Static
  config.middleware.delete Rack::Lock
  config.middleware.delete Rack::Head
  config.middleware.delete Rack::ConditionalGet
  config.middleware.delete Rack::ETag
  config.middleware.delete Rack::MethodOverride

  config.generators do |g|
    g.orm             false
    g.stylesheets     false
    g.helper          false
    g.template_engine false
    g.assets          false
  end
end
