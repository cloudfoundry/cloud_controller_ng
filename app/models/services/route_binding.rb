module VCAP::CloudController
  class RouteBinding
    attr_reader :route, :service_instance

    def initialize(route, service_instance)
      @route            = route
      @service_instance = service_instance
    end

    def required_parameters
      { route: route.uri }
    end

    delegate :guid, :space, :in_suspended_org?, to: :route
    delegate :service, :service_broker, :service_plan, :client, to: :service_instance
  end
end
