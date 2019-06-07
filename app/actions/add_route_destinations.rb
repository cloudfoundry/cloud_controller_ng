module VCAP::CloudController
  class AddRouteDestinations
    def self.add(message, route, apps_hash)
      existing_route_mappings = route.route_mappings.map do |rm|
        {
          app_guid: rm.app_guid,
          route_guid: rm.route_guid,
          process_type: rm.process_type,
          app_port: rm.app_port,
          route: route
        }
      end

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

      saveable_route_mappings = new_route_mappings - existing_route_mappings
      RouteMappingModel.db.transaction do
        saveable_route_mappings.each do |rm|
          route_mapping = RouteMappingModel.new(rm)
          route_mapping.save
          app = apps_hash[route_mapping.app_guid]
          app.processes_dataset.where(type: route_mapping.process_type).each do |process|
            ProcessRouteHandler.new(process).update_route_information
          end

          Copilot::Adapter.map_route(route_mapping)
        end
      end

      route.reload
    end
  end
end
