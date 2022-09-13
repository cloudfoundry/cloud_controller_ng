module VCAP::CloudController
  module Diego
    class Protocol
      class RoutingInfo
        attr_reader :process

        def initialize(process)
          @process = process
        end

        def routing_info
          http_info_obj = http_info
          tcp_info_obj  = tcp_info

          route_info                    = {}
          route_info['http_routes']     = http_info_obj unless http_info_obj.blank?
          route_info['tcp_routes']      = tcp_info_obj unless tcp_info_obj.blank?
          route_info['internal_routes'] = internal_routes
          route_info
        rescue RoutingApi::RoutingApiDisabled
          raise CloudController::Errors::ApiError.new_from_details('RoutingApiDisabled')
        rescue RoutingApi::RoutingApiUnavailable
          raise CloudController::Errors::ApiError.new_from_details('RoutingApiUnavailable')
        rescue RoutingApi::UaaUnavailable
          raise CloudController::Errors::ApiError.new_from_details('UaaUnavailable')
        end

        private

        def http_info
          relevant_http_routes = process.routes.reject do |route|
            route.internal? || route.tcp?
          end

          relevant_http_routes.each_with_object([]) do |r, http_info|
            r.route_mappings.each do |route_mapping|
              info = { 'hostname' => r.uri }
              info['route_service_url'] = r.route_binding.route_service_url if r.route_binding && r.route_binding.route_service_url
              info['router_group_guid'] = r.domain.router_group_guid if r.domain.is_a?(SharedDomain) && !r.domain.router_group_guid.nil?
              info['port'] = get_port_to_use(route_mapping)
              info['protocol'] = route_mapping.protocol
              http_info.push(info)
            end
          end
        end

        def tcp_info
          relevant_tcp_routes = process.routes.select do |r|
            r.tcp? && !r.internal?
          end

          relevant_tcp_routes.each_with_object([]) do |r, tcp_info|
            r.route_mappings.each do |route_mapping|
              info = { 'router_group_guid' => r.domain.router_group_guid }
              info['external_port'] = r.port
              info['container_port'] = get_port_to_use(route_mapping)
              tcp_info.push(info)
            end
          end
        end

        def internal_routes
          process.routes.select(&:internal?).map do |r|
            { 'hostname' => "#{r.host}.#{r.domain.name}" }
          end
        end

        def get_port_to_use(route_mapping)
          return route_mapping.app_port if route_mapping.has_app_port_specified?
          return process.docker_ports.first if process.docker? && process.docker_ports.present?
          return process.ports.first if process.ports.present?
          return VCAP::CloudController::ProcessModel::DEFAULT_DOCKER_PORT if process.docker?

          VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT
        end
      end
    end
  end
end
