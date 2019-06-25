module VCAP::CloudController
  class SpaceDeleteUnmappedRoutes
    def delete(space)
      space.db.transaction do
        space.lock!

        space.routes_dataset.
          exclude(guid: RouteMappingModel.select(:route_guid)).
          exclude(id: RouteBinding.select(:route_id)).
          delete
      end
    end
  end
end
