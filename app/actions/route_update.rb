module VCAP::CloudController
  class RouteUpdate
    def update(route:, message:)
      Route.db.transaction do
        route.options = route.options.symbolize_keys.merge(message.options).compact if message.requested?(:options)

        route.save
        MetadataUpdate.update(route, message)
      end

      route
    end
  end
end
