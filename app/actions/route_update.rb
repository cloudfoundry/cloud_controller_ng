module VCAP::CloudController
  class RouteUpdate
    def update(route:, message:)
      Route.db.transaction do
        if message.requested?(:options)
          route.options = route.options.symbolize_keys.merge(message.options).compact
          route.apps.each do |process|
            ProcessRouteHandler.new(process).notify_backend_of_route_update
          end
        end
        route.save
        MetadataUpdate.update(route, message)
      end
      route
    end
  end
end
