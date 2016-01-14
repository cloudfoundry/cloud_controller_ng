module VCAP::CloudController
  class RouteBindingMessage < VCAP::RestAPI::Message
    optional :parameters, Hash
  end
end
