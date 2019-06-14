module VCAP::CloudController
  class DestinationDeleteAction
    def self.delete(route_mapping)
      RouteMappingModel.db.transaction do
        Copilot::Adapter.unmap_route(route_mapping)

        route_mapping.destroy
      end
    end
  end
end
