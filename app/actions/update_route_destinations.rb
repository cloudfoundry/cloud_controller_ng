module VCAP::CloudController
  class UpdateRouteDestinations
    class << self
      def add(message, route, user_audit_info)
        existing_route_mappings = route_to_mapping_hashes(route)
        new_route_mappings = message_to_mapping_hashes(message, route)
        to_add = new_route_mappings - existing_route_mappings

        update(route, to_add, [], user_audit_info)
      end

      def replace(message, route, user_audit_info)
        existing_route_mappings = route_to_mapping_hashes(route)
        new_route_mappings = message_to_mapping_hashes(message, route)
        to_add = new_route_mappings - existing_route_mappings
        to_delete = existing_route_mappings - new_route_mappings

        update(route, to_add, to_delete, user_audit_info)
      end

      def delete(destination, route, user_audit_info)
        to_delete = [destination_to_mapping_hash(route, destination)]

        update(route, [], to_delete, user_audit_info)
      end

      private

      def update(route, to_add, to_delete, user_audit_info)
        RouteMappingModel.db.transaction do
          to_delete.each do |rm|
            route_mapping = RouteMappingModel.find(rm)
            route_mapping.destroy

            Copilot::Adapter.unmap_route(route_mapping)
            update_route_information(route_mapping)
          end

          to_add.each do |rm|
            route_mapping = RouteMappingModel.new(rm)
            route_mapping.save

            Copilot::Adapter.map_route(route_mapping)
            update_route_information(route_mapping)

            Repositories::RouteEventRepository.new.record_route_map(route_mapping, user_audit_info)
          end
        end

        route.reload
      end

      def update_route_information(route_mapping)
        route_mapping.processes.each do |process|
          ProcessRouteHandler.new(process).update_route_information(perform_validation: false)
        end
      end

      def message_to_mapping_hashes(message, route)
        new_route_mappings = []
        message.destinations.each do |dst|
          app_guid = HashUtils.dig(dst, :app, :guid)
          process_type = HashUtils.dig(dst, :app, :process, :type) || 'web'

          new_route_mappings << {
            app_guid: app_guid,
            route_guid: route.guid,
            route: route,
            process_type: process_type,
            app_port: ProcessModel::DEFAULT_HTTP_PORT
          }
        end

        new_route_mappings
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
          route: route
        }
      end
    end
  end
end
