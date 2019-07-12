module VCAP::CloudController
  class UpdateRouteDestinations
    class Error < StandardError; end

    class << self
      def add(new_route_mappings, route, user_audit_info, manifest_triggered: false)
        existing_route_mappings = route_to_mapping_hashes(route)
        new_route_mappings = add_route(new_route_mappings, route)
        if existing_route_mappings.any? { |rm| rm[:weight] }
          raise Error.new('Destinations cannot be inserted when there are weighted destinations already configured.')
        end

        to_add = new_route_mappings - existing_route_mappings

        update(route, to_add, [], user_audit_info, manifest_triggered)
      end

      def replace(new_route_mappings, route, user_audit_info, manifest_triggered: false)
        existing_route_mappings = route_to_mapping_hashes(route)
        new_route_mappings = add_route(new_route_mappings, route)
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
          to_delete.each do |rm|
            route_mapping = RouteMappingModel.find(rm)
            route_mapping.destroy

            Copilot::Adapter.unmap_route(route_mapping)
            update_route_information(route_mapping)

            Repositories::AppEventRepository.new.record_unmap_route(
              user_audit_info,
              route_mapping,
              manifest_triggered: manifest_triggered
            )
          end

          to_add.each do |rm|
            route_mapping = RouteMappingModel.new(rm)
            route_mapping.save

            Copilot::Adapter.map_route(route_mapping)
            update_route_information(route_mapping)

            Repositories::AppEventRepository.new.record_map_route(
              user_audit_info,
              route_mapping,
              manifest_triggered: manifest_triggered
            )
          end
        end

        route.reload
      end

      def update_route_information(route_mapping)
        route_mapping.processes.each do |process|
          ProcessRouteHandler.new(process).update_route_information(perform_validation: false)
        end
      end

      def add_route(destinations, route)
        destinations.map do |dst|
          dst.merge({ route: route, route_guid: route.guid })
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
          weight: destination.weight
        }
      end
    end
  end
end
