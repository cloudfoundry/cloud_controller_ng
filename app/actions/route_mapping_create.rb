module VCAP::CloudController
  class RouteMappingCreate
    class InvalidRouteMapping < StandardError
    end
    class DuplicateRouteMapping < InvalidRouteMapping
    end
    class SpaceMismatch < InvalidRouteMapping
    end
    class RoutingApiDisabledError < InvalidRouteMapping
    end
    class RouteServiceNotSupportedError < InvalidRouteMapping
    end

    DUPLICATE_MESSAGE     = 'Duplicate Route Mapping - Only one route mapping may exist for an application, route, and port'.freeze
    INVALID_SPACE_MESSAGE = 'the app and route must belong to the same space'.freeze

    def initialize(user_audit_info, route, process)
      @user_audit_info = user_audit_info
      @app             = process.app
      @route           = route
      @process         = process
    end

    def add(message)
      validate!

      route_mapping = RouteMappingModel.new(
        app:          app,
        route:        route,
        process_type: message.process_type,
        app_port:     VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT
      )

      route_handler = ProcessRouteHandler.new(process)

      RouteMappingModel.db.transaction do
        route_mapping.save
        route_handler.update_route_information

        app_event_repository.record_map_route(
          app,
          route,
          user_audit_info,
          route_mapping: route_mapping
        )
      end

      route_mapping
    rescue Sequel::ValidationFailed => e
      if e.errors && e.errors.on([:app_guid, :route_guid, :process_type, :app_port]) && e.errors.on([:app_guid, :route_guid, :process_type, :app_port]).include?(:unique)
        raise DuplicateRouteMapping.new(DUPLICATE_MESSAGE)
      end

      raise InvalidRouteMapping.new(e.message)
    end

    private

    attr_reader(:app, :route, :process, :user_audit_info)

    def validate!
      validate_routing_api_enabled!
      validate_route_services!
      validate_space!
    end

    def validate_space!
      raise SpaceMismatch.new(INVALID_SPACE_MESSAGE) unless app.space.guid == route.space.guid
    end

    def app_event_repository
      Repositories::AppEventRepository.new
    end

    def validate_route_services!
      raise RouteServiceNotSupportedError.new if !route.route_service_url.nil? && !process.diego?
    end

    def validate_routing_api_enabled!
      if Config.config.get(:routing_api).nil? && route.domain.shared? && route.domain.router_group_guid
        raise RoutingApiDisabledError.new('Routing API is disabled')
      end
    end
  end
end
