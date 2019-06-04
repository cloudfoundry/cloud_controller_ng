module VCAP::CloudController
  class RouteUpdate
    def update(route:, message:)
      Route.db.transaction do
        MetadataUpdate.update(route, message)
      end

      route
    end
  end
end
