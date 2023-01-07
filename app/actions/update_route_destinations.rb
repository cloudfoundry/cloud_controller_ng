module VCAP::CloudController
  class UpdateRouteDestinations
    class Error < StandardError
    end

    class DuplicateDestinationError < StandardError
    end

    MAX_DESTINATIONS_FOR_ROUTE = 100

    class << self
      def add(new_route_mappings, route, apps_hash, user_audit_info, manifest_triggered: false)
        existing_route_mappings = route_to_mapping_hashes(route)
        new_route_mappings = update_port(new_route_mappings, apps_hash)
        new_route_mappings = update_protocol(new_route_mappings, route)
        new_route_mappings = add_route(new_route_mappings, route)

        validate_max_destinations!(existing_route_mappings, new_route_mappings)
        validate_unique!(new_route_mappings)

        if existing_route_mappings.any? { |rm| rm[:weight] }
          raise Error.new('Destinations cannot be inserted when there are weighted destinations already configured.')
        end

        to_add = compare_destination_hashes(new_route_mappings, existing_route_mappings)

        update(route, to_add, [], user_audit_info, manifest_triggered)
      end

      def replace(new_route_mappings, route, apps_hash, user_audit_info, manifest_triggered: false)
        existing_route_mappings = route_to_mapping_hashes(route)
        new_route_mappings = update_port(new_route_mappings, apps_hash)
        new_route_mappings = update_protocol(new_route_mappings, route)
        new_route_mappings = add_route(new_route_mappings, route)

        validate_max_destinations!([], new_route_mappings)
        validate_unique!(new_route_mappings)

        to_add = new_route_mappings - existing_route_mappings
        to_delete = existing_route_mappings - new_route_mappings

        update(route, to_add, to_delete, user_audit_info, manifest_triggered)
      end

      def delete(destination, route, user_audit_info)
        if destination.weight
          raise Error.new('Weighted destinations cannot be deleted individually.')
        end

        to_delete = [destination_to_mapping_hash(route, destination)]

        update(route, [], to_delete, user_audit_info, false)
      end

      private

      def update(route, to_add, to_delete, user_audit_info, manifest_triggered)
        RouteMappingModel.db.transaction do
          processes_to_ports_map = {}

          to_delete.each do |rm|
            rm.delete(:protocol)
            route_mapping = RouteMappingModel[rm]
            route_mapping.destroy

            Copilot::Adapter.unmap_route(route_mapping)
            route_mapping.processes.each do |process|
              processes_to_ports_map[process] ||= { to_add: [], to_delete: [] }
              processes_to_ports_map[process][:to_delete] << route_mapping.app_port unless process.route_mappings_dataset.any? do |process_route_mapping|
                process_route_mapping.guid != route_mapping.guid && process_route_mapping.app_port == route_mapping.app_port
              end
            end

            Repositories::AppEventRepository.new.record_unmap_route(
              user_audit_info,
              route_mapping,
              manifest_triggered: manifest_triggered
            )
          end

          to_add.each do |rm|
            validate_protocol_matches!(rm)

            route_mapping = RouteMappingModel.new(rm)
            route_mapping.save

            Copilot::Adapter.map_route(route_mapping)
            route_mapping.processes.each do |process|
              processes_to_ports_map[process] ||= { to_add: [], to_delete: [] }
              processes_to_ports_map[process][:to_add] << route_mapping.app_port
            end

            Repositories::AppEventRepository.new.record_map_route(
              user_audit_info,
              route_mapping,
              manifest_triggered: manifest_triggered
            )
          end

          update_processes(processes_to_ports_map)
        end

        route.reload

        route
      end

      def update_processes(processes_to_ports_map)
        processes_to_ports_map.each do |process, ports_hash|
          ports_to_add = ports_hash[:to_add].uniq.reject { |port| port == ProcessModel::NO_APP_PORT_SPECIFIED }
          ports_to_delete = ports_hash[:to_delete].uniq.reject { |port| port == ProcessModel::NO_APP_PORT_SPECIFIED }

          updated_ports = ((process.ports || []) - ports_to_delete + ports_to_add).uniq
          if updated_ports.empty?
            updated_ports = if process.app.buildpack?
                              ProcessModel::DEFAULT_PORTS
                            end
          end

          process.skip_process_version_update = true
          ProcessRouteHandler.new(process).update_route_information(
            perform_validation: false,
            updated_ports: updated_ports
          )
        end
      rescue Sequel::ValidationFailed => e
        raise Error.new(e.message)
      end

      def compare_destination_hashes(new_route_mappings, existing_route_mappings)
        new_route_mappings.reject do |new|
          matching_route_mapping = existing_route_mappings.find do |existing|
            new.slice(:app_guid, :process_type, :route_guid, :app_port) == existing.slice(:app_guid, :process_type, :route_guid, :app_port)
          end

          if matching_route_mapping && matching_route_mapping[:protocol] != new[:protocol]
            raise Error.new("Cannot add destination with protocol: #{new[:protocol]}. Destination already exists for route: #{new[:route].uri}, app: #{new[:app_guid]}, " \
                            "process: #{new[:process_type]}, and protocol: #{matching_route_mapping[:protocol]}.")
          end

          matching_route_mapping
        end
      end

      def add_route(destinations, route)
        destinations.map do |dst|
          dst.merge({ route: route, route_guid: route.guid })
        end
      end

      def update_port(destinations, apps_hash)
        destinations.each do |dst|
          if dst[:app_port].nil?
            app = apps_hash[dst[:app_guid]]

            dst[:app_port] = default_port(app)
          end
        end
      end

      def update_protocol(destinations, route)
        destinations.each do |dst|
          if dst[:protocol].nil?
            dst[:protocol] = RouteMappingModel::DEFAULT_PROTOCOL_MAPPING[route.protocol]
          end
        end
      end

      def default_port(app)
        if app.buildpack?
          ProcessModel::DEFAULT_HTTP_PORT
        else
          ProcessModel::NO_APP_PORT_SPECIFIED
        end
      end

      def route_to_mapping_hashes(route)
        route.route_mappings.map do |destination|
          destination_to_mapping_hash(route, destination)
        end
      end

      def destination_to_mapping_hash(route, destination)
        {
          app_guid: destination.app_guid,
          route_guid: destination.route_guid,
          process_type: destination.process_type,
          app_port: destination.app_port,
          route: route,
          weight: destination.weight,
          protocol: destination.protocol
        }
      end

      def route_resource_manager
        CloudController::DependencyLocator.instance.route_resource_manager
      end

      def validate_unique!(new_route_mappings)
        raise DuplicateDestinationError.new('Destinations cannot contain duplicate entries') if new_route_mappings.any? { |rm| new_route_mappings.count(rm) > 1 }
      end

      def validate_protocol_matches!(route_destination)
        destination_protocol = route_destination[:protocol]
        return unless destination_protocol

        route_protocol = route_destination[:route].protocol
        dest_to_route_map = { 'tcp' => 'tcp', 'http1' => 'http', 'http2' => 'http' }

        raise protocol_mismatch_error(route_protocol, destination_protocol) if route_protocol != dest_to_route_map[destination_protocol]
      end

      def protocol_mismatch_error(route_protocol, destination_protocol)
        valid_options = { 'tcp' => 'tcp', 'http' => 'http1, http2' }
        Error.new("Cannot use '#{destination_protocol}' protocol for #{route_protocol} routes; valid options are: [#{valid_options[route_protocol]}].")
      end

      def validate_max_destinations!(existing_route_mappings, new_route_mappings)
        total_route_mapping_count = existing_route_mappings.count + new_route_mappings.count

        if total_route_mapping_count > MAX_DESTINATIONS_FOR_ROUTE
          raise Error.new('Routes can be mapped to at most 100 destinations.')
        end
      end
    end
  end
end
