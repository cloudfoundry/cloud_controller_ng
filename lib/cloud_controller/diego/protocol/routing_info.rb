module VCAP::CloudController
  module Diego
    class Protocol
      class RoutingInfo
        attr_reader :process

        def initialize(process)
          @process = process
        end

        def routing_info
          process_eager = ProcessModel.eager(route_mappings: { route: %i[domain route_binding] }).where(id: process.id).all

          return {} if process_eager.empty?

          http_info_obj = http_info(process_eager)
          tcp_info_obj  = tcp_info(process_eager)

          route_info                    = {}
          route_info['http_routes']     = http_info_obj if http_info_obj.present?
          route_info['tcp_routes']      = tcp_info_obj if tcp_info_obj.present?
          route_info['internal_routes'] = internal_routes(process_eager)
          route_info
        rescue RoutingApi::RoutingApiDisabled
          raise CloudController::Errors::ApiError.new_from_details('RoutingApiDisabled')
        rescue RoutingApi::RoutingApiUnavailable
          raise CloudController::Errors::ApiError.new_from_details('RoutingApiUnavailable')
        rescue RoutingApi::UaaUnavailable
          raise CloudController::Errors::ApiError.new_from_details('UaaUnavailable')
        end

        private

        def http_info(process_eager)
          route_mappings = process_eager[0].route_mappings.reject do |route_mapping|
            route_mapping.route.internal? || route_mapping.route.tcp?
          end

          route_mappings.map do |route_mapping|
            r = route_mapping.route
            info = { 'hostname' => r.uri }
            info['route_service_url'] = r.route_binding.route_service_url if r.route_binding && r.route_binding.route_service_url
            info['router_group_guid'] = r.domain.router_group_guid if r.domain.is_a?(SharedDomain) && !r.domain.router_group_guid.nil?
            info['port'] = get_port_to_use(route_mapping)
            info['protocol'] = route_mapping.protocol
            info['options'] = r.options if r.options
            info
          end
        end

        def tcp_info(process_eager)
          route_mappings = process_eager[0].route_mappings.select do |route_mapping|
            r = route_mapping.route
            r.tcp? && !r.internal?
          end

          route_mappings.map do |route_mapping|
            r = route_mapping.route
            info = { 'router_group_guid' => r.domain.router_group_guid }
            info['external_port'] = r.port
            info['container_port'] = get_port_to_use(route_mapping)
            info
          end
        end

        def internal_routes(process_eager)
          route_mappings = process_eager[0].route_mappings.select do |route_mapping|
            route_mapping.route.internal?
          end

          route_mappings.map do |route_mapping|
            r = route_mapping.route
            { 'hostname' => "#{r.host}.#{r.domain.name}" }
          end
        end

        def get_port_to_use(route_mapping)
          return route_mapping.app_port if route_mapping.has_app_port_specified?
          return process.docker_ports.first if process.docker? && process.docker_ports.present?
          return process.ports.first if process.ports.present?

          VCAP::CloudController::ProcessModel::DEFAULT_HTTP_PORT
        end
      end
    end
  end
end
