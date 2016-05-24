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
            route_app_port_map[r.id].each do |app_port|
              if r.domain.router_group_guid.nil?
                info = { 'hostname' => r.uri }
                info['route_service_url'] = r.route_binding.route_service_url if r.route_binding && r.route_binding.route_service_url
                info['port'] = app_port
                http_info.push(info)
              elsif !route_app_port_map[r.id].blank?
                info = { 'router_group_guid' => r.domain.router_group_guid }
                info['external_port'] = r.port
                info['container_port'] = app_port
                tcp_info.push(info)
              end
            end
          end
          route_info = {}
          route_info['http_routes'] = http_info unless http_info.blank?
          route_info['tcp_routes'] = tcp_info unless tcp_info.blank?
          route_info
        end

        private

        def route_id_app_ports_map
          process.route_mappings(true).each_with_object({}) do |route_map, route_app_port_map|
            route_app_port_map[route_map.route_id] = [] if route_app_port_map[route_map.route_id].nil?
            if route_map.app_port.present?
              route_app_port_map[route_map.route_id].push(route_map.app_port)
            elsif process.docker? && process.docker_ports.present?
              route_app_port_map[route_map.route_id].push(process.docker_ports.first)
            else
              route_app_port_map[route_map.route_id].push(VCAP::CloudController::App::DEFAULT_HTTP_PORT)
            end
          end
        end
      end
    end
  end
end
