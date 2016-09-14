require 'actions/route_mapping_create'

module VCAP::CloudController
  module V2
    class RouteMappingCreate
      class InvalidRouteMapping < StandardError; end
      class TcpRoutingDisabledError < InvalidRouteMapping; end
      class AppPortNotSupportedError < InvalidRouteMapping; end
      class RouteServiceNotSupportedError < InvalidRouteMapping; end

      def initialize(user, user_email, route, process)
        @user       = user
        @user_email = user_email
        @route      = route
        @process    = process
      end

      def add(request_attrs)
        validate_routing_api_enabled!
        validate_route_services!
        validate_port!(request_attrs)

        message = RouteMappingsCreateMessage.new({
          relationships: {
            app:     { guid: @process.app.guid },
            route:   { guid: @route.guid },
            process: { type: @process.type }
          },
          app_port:      get_port(request_attrs)
        })

        VCAP::CloudController::RouteMappingCreate.new(@user, @user_email, @process.app, @route, @process, message).add
      end

      private

      def get_port(request_attrs)
        request_attrs.key?('app_port') ? request_attrs['app_port'] : @process.ports.try(:first)
      end

      def validate_route_services!
        raise RouteServiceNotSupportedError.new if !@route.route_service_url.nil? && !@process.diego?
      end

      def validate_routing_api_enabled!
        if @route.domain.shared? && @route.domain.tcp? && Config.config[:routing_api].nil?
          raise TcpRoutingDisabledError.new('TCP routing is disabled')
        end
      end

      def validate_port!(request_attrs)
        raise AppPortNotSupportedError.new if request_attrs.key?('app_port') && @process.dea?
      end
    end
  end
end
