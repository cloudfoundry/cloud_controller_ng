module VCAP::CloudController
  class RouteUpdate
    def update(route:, message:)
      Route.db.transaction do
        if message.requested?(:options)
          # Merge existing options with new options from message
          existing_options = route.options&.deep_symbolize_keys || {}
          merged_options = existing_options.merge(message.options).compact

          # Set the options on the route (cleanup is handled by model)
          route.options = merged_options
        end

        route.save
        MetadataUpdate.update(route, message)
      end

      if message.requested?(:options)
        route.apps.each do |process|
          ProcessRouteHandler.new(process).notify_backend_of_route_update
        end
      end
      route
    end
  end
end
