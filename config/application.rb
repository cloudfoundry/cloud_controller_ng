require 'action_controller/railtie'

class Application < ::Rails::Application
  config.exceptions_app = self.routes

  # For Rails 5 / Rack 2 - this is how to add a new parser
  original_parsers = ActionDispatch::Request.parameter_parsers
  yaml_parser = lambda { |body| YAML.safe_load(body).with_indifferent_access }
  new_parsers = original_parsers.merge({
    Mime::Type.lookup('application/x-yaml') => yaml_parser,
    Mime::Type.lookup('text/yaml') => yaml_parser,
  })
  ActionDispatch::Request.parameter_parsers = new_parsers

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
end
