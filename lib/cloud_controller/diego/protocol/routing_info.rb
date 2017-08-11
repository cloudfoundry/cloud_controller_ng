module VCAP::CloudController
  module Diego
    class Protocol
      class RoutingInfo
        attr_reader :process

        def initialize(process)
          @process = process
        end

        def routing_info
          route_app_port_map = route_id_app_ports_map

          http_info = []
          tcp_info = []
          process.routes.each do |r|
            route_app_port_map[r.guid].each do |app_port|
              if r.domain.is_a?(SharedDomain) && !r.domain.router_group_guid.nil?
                if r.domain.tcp? && !route_app_port_map[r.guid].blank?
                  info = { 'router_group_guid' => r.domain.router_group_guid }
                  info['external_port'] = r.port
                  info['container_port'] = app_port
                  tcp_info.push(info)
                else
                  info = { 'hostname' => r.uri }
                  info['route_service_url'] = r.route_binding.route_service_url if r.route_binding && r.route_binding.route_service_url
                  info['port'] = app_port
                  info['router_group_guid'] = r.domain.router_group_guid
                  http_info.push(info)
                end
              else
                info = { 'hostname' => r.uri }
                info['route_service_url'] = r.route_binding.route_service_url if r.route_binding && r.route_binding.route_service_url
                info['port'] = app_port
                http_info.push(info)
              end
            end
          end
          route_info = {}
          route_info['http_routes'] = http_info unless http_info.blank?
          route_info['tcp_routes'] = tcp_info unless tcp_info.blank?
          route_info
        rescue RoutingApi::RoutingApiDisabled
          raise CloudController::Errors::ApiError.new_from_details('RoutingApiDisabled')
        rescue RoutingApi::RoutingApiUnavailable
          raise CloudController::Errors::ApiError.new_from_details('RoutingApiUnavailable')
        rescue RoutingApi::UaaUnavailable
          raise CloudController::Errors::ApiError.new_from_details('UaaUnavailable')
        end

        private

        def route_id_app_ports_map
          process.route_mappings(reload: true).each_with_object({}) do |route_map, route_app_port_map|
            route_app_port_map[route_map.route_guid] = [] if route_app_port_map[route_map.route_guid].nil?
            if route_map.app_port.present? && route_map.app_port != VCAP::CloudController::ProcessModel::NO_APP_PORT_SPECIFIED
              route_app_port_map[route_map.route_guid].push(route_map.app_port)
            elsif process.docker? && process.docker_ports.present?
              route_app_port_map[route_map.route_guid].push(process.docker_ports.first)
            elsif process.ports.present?
              route_app_port_map[route_map.route_guid].push(process.ports.first)
            else
              route_app_port_map[route_map.route_guid].push(VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT)
            end
          end
        end
      end
    end
  end
end
