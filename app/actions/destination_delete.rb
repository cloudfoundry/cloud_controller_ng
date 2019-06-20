module VCAP::CloudController
  class DestinationDeleteAction
    def self.delete(route_mapping)
      RouteMappingModel.db.transaction do
        Copilot::Adapter.unmap_route(route_mapping)

        route_handlers = route_mapping.processes.map do |process|
          ProcessRouteHandler.new(process)
        end

        route_mapping.destroy
        route_handlers.each { |handler| handler.update_route_information(perform_validation: false) }
      end
    end
  end
end
