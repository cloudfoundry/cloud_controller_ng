module VCAP::CloudController
  module Diego
    class Protocol
      class RoutingInfo
        attr_reader :process

        def initialize(process)
          @process = process
        end

        # rubocop:todo Metrics/CyclomaticComplexity
        def routing_info
          route_app_port_map = route_id_app_ports_map

          http_info = []
          tcp_info = []

          process.routes.reject(&:internal?).each do |r|
            route_app_port_map[r.guid].each do |route_mapping_info|
              if r.domain.is_a?(SharedDomain) && !r.domain.router_group_guid.nil?
                if r.domain.tcp? && !route_app_port_map[r.guid].blank?
                  info = { 'router_group_guid' => r.domain.router_group_guid }
                  info['external_port'] = r.port
                  info['container_port'] = route_mapping_info[:app_port]
                  tcp_info.push(info)
                else
                  info = { 'hostname' => r.uri }
                  info['route_service_url'] = r.route_binding.route_service_url if r.route_binding && r.route_binding.route_service_url
                  info['port'] = route_mapping_info[:app_port]
                  info['router_group_guid'] = r.domain.router_group_guid
                  info['http_version'] = route_mapping_info[:http_version]
                  http_info.push(info)
                end
              else
                info = { 'hostname' => r.uri }
                info['route_service_url'] = r.route_binding.route_service_url if r.route_binding && r.route_binding.route_service_url
                info['port'] = route_mapping_info[:app_port]
                info['http_version'] = route_mapping_info[:http_version]
                http_info.push(info)
              end
            end
          end

          internal_routes = []
          process.routes.select(&:internal?).each do |r|
            internal_routes << { 'hostname' => "#{r.host}.#{r.domain.name}" }
          end

          route_info = {}
          route_info['http_routes'] = http_info unless http_info.blank?
          route_info['tcp_routes'] = tcp_info unless tcp_info.blank?
          route_info['internal_routes'] = internal_routes
          route_info
        rescue RoutingApi::RoutingApiDisabled
          raise CloudController::Errors::ApiError.new_from_details('RoutingApiDisabled')
        rescue RoutingApi::RoutingApiUnavailable
          raise CloudController::Errors::ApiError.new_from_details('RoutingApiUnavailable')
        rescue RoutingApi::UaaUnavailable
          raise CloudController::Errors::ApiError.new_from_details('UaaUnavailable')
        end
        # rubocop:enable Metrics/CyclomaticComplexity

        private

        def route_id_app_ports_map
          process.route_mappings(reload: true).each_with_object({}) do |route_mapping, route_app_port_map|
            route_app_port_map[route_mapping.route_guid] ||= []
            route_app_port_map[route_mapping.route_guid].push({app_port: get_port_to_use(process, route_mapping), http_version: route_mapping.http_version})
          end
        end

        def get_port_to_use(process, route_mapping)
          return route_mapping.app_port if route_mapping.has_app_port_specified?
          return process.docker_ports.first if process.docker? && process.docker_ports.present?
          return process.ports.first if process.ports.present?

          VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT
        end
      end
    end
  end
end
