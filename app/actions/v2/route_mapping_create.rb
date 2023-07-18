module VCAP::CloudController
  module V2
    class RouteMappingCreate
      class InvalidRouteMapping < StandardError
      end
      class DuplicateRouteMapping < InvalidRouteMapping
      end
      class UnavailableAppPort < InvalidRouteMapping
      end
      class SpaceMismatch < InvalidRouteMapping
      end
      class RoutingApiDisabledError < InvalidRouteMapping
      end

      DUPLICATE_MESSAGE                   = 'Duplicate Route Mapping - Only one route mapping may exist for an application, route, and port'.freeze
      INVALID_SPACE_MESSAGE               = 'the app and route must belong to the same space'.freeze
      UNAVAILABLE_APP_PORT_MESSAGE_FORMAT = 'Port %<port>s is not available on the app\'s process'.freeze
      NO_PORT_REQUESTED                   = 'Port must be specified when mapping to a non-web process'.freeze

      def initialize(user_audit_info, route, process, request_attrs, logger)
        @user_audit_info = user_audit_info
        @app             = process.app
        @route           = route
        @process         = process
        @request_attrs   = request_attrs
        @logger          = logger
      end

      def add
        validate!

        route_mapping = RouteMappingModel.new(
          app:          app,
          route:        route,
          process_type: process.type,
          app_port:     port_with_defaults
        )

        route_handler = ProcessRouteHandler.new(process)

        RouteMappingModel.db.transaction do
          route_mapping.save
          route_handler.update_route_information

          app_event_repository.record_map_route(
            user_audit_info,
            route_mapping
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

      attr_reader :request_attrs, :user_audit_info, :app, :route, :process

      def route_resource_manager
        @route_resource_manager ||= CloudController::DependencyLocator.instance.route_resource_manager
      end

      def requested_port
        @requested_port ||= request_attrs.key?('app_port') ? request_attrs['app_port'] : process.ports.try(:first)
      end

      def port_with_defaults
        port = requested_port
        port ||= app.docker? ? ProcessModel::NO_APP_PORT_SPECIFIED : ProcessModel::DEFAULT_HTTP_PORT
        port
      end

      def validate!
        validate_routing_api_enabled!
        validate_space!
        validate_available_port!
      end

      def validate_available_port!
        return if process.blank?

        validate_web_port!
        validate_non_web_port!
      end

      def validate_non_web_port!
        return if process.web?

        raise InvalidRouteMapping.new(NO_PORT_REQUESTED) if requested_port.nil?

        raise_unavailable_port! unless available_ports.present? && available_ports.include?(requested_port.to_i)
      end

      def validate_web_port!
        return unless process.web?
        return if requested_port.nil?
        return if process.docker?

        raise_unavailable_port! unless available_ports.include?(requested_port.to_i)
      end

      def validate_space!
        raise SpaceMismatch.new(INVALID_SPACE_MESSAGE) unless app.space_guid == route.space.guid
      end

      def app_event_repository
        Repositories::AppEventRepository.new
      end

      def raise_unavailable_port!
        raise UnavailableAppPort.new(sprintf(UNAVAILABLE_APP_PORT_MESSAGE_FORMAT, port: requested_port))
      end

      def available_ports
        @available_ports ||= process.open_ports
      end

      def validate_routing_api_enabled!
        if Config.config.get(:routing_api).nil? && route.domain.shared? && route.domain.router_group_guid
          raise RoutingApiDisabledError.new('Routing API is disabled')
        end
      end
    end
  end
end
