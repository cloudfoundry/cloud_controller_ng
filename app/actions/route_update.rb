module VCAP::CloudController
  class RouteUpdate
    def update(route:, message:)
      Route.db.transaction do
        if message.requested?(:options)
          # Merge existing options with new options from message
          existing_options = route.options&.deep_symbolize_keys || {}
          merged_options = existing_options.merge(message.options).compact

          # Remove hash-specific options if switching to non-hash loadbalancing
          if merged_options[:loadbalancing] && merged_options[:loadbalancing] != 'hash'
            merged_options.delete(:hash_header)
            merged_options.delete(:hash_balance)
          end

          # Set the options on the route
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
