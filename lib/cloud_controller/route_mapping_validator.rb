module VCAP::CloudController
  class RouteMappingValidator
    class ValidationError < StandardError
    end
    class TcpRoutingDisabledError < ValidationError
    end
    class AppInvalidError < ValidationError
    end
    class RouteInvalidError < ValidationError
    end

    def initialize(route, app)
      @config = Config.config
      @route = route
      @app = app
    end

    def validate
      validate_app_exists
      validate_route_exists
      if @route.domain.shared? && @route.domain.tcp?
        validate_routing_api_enabled
      end
    end

    private

    def validate_app_exists
      raise AppInvalidError if @app.nil?
    end

    def validate_route_exists
      raise RouteInvalidError if @route.nil?
    end

    def validate_routing_api_enabled
      raise TcpRoutingDisabledError.new('TCP routing is disabled') if @config[:routing_api].nil?
    end
  end
end
