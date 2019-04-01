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

    DUPLICATE_MESSAGE = 'Duplicate Route Mapping - Only one route mapping may exist for an application, route, and port'.freeze

    class << self
      def add(user_audit_info:, route:, process_type:, app:, manifest_triggered: false, weight: nil)
        validate!(app, route)

        route_mapping_attrs = {
          app: app,
          route: route,
          process_type: process_type,
          app_port: VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT,
          weight: weight
        }.compact

        route_mapping = RouteMappingModel.new(route_mapping_attrs)

        RouteMappingModel.db.transaction do
          route_mapping.save

          app.processes_dataset.where(type: process_type).each do |process|
            ProcessRouteHandler.new(process).update_route_information
          end

          Copilot::Adapter.map_route(route_mapping)

          Repositories::AppEventRepository.new.record_map_route(
            app,
            route,
            user_audit_info,
            route_mapping: route_mapping,
            manifest_triggered: manifest_triggered
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

      def logger
        @logger ||= Steno.logger('cc.route_mapping_create')
      end

      def validate!(app, route)
        validate_routing_api_enabled!(route)
        validate_space!(app, route)
      end

      def validate_space!(app, route)
        return if app.space.guid == route.space.guid

        raise SpaceMismatch.new("The app cannot be mapped to route #{route.uri} because the route is not in this space. Apps must be mapped to routes in the same space.")
      end

      def validate_routing_api_enabled!(route)
        if Config.config.get(:routing_api).nil? && route.domain.shared? && route.domain.router_group_guid
          raise RoutingApiDisabledError.new('Routing API is disabled')
        end
      end
    end
  end
end
