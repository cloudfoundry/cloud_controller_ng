module VCAP::CloudController
  class RouteUpdate
    def update(route:, message:)
      Route.db.transaction do
        if message.requested?(:options)
          merged_options = message.options.compact

          # Clean up invalid option combinations
          # If loadbalancing is not 'hash', remove hash-specific options
          if merged_options[:loadbalancing] && merged_options[:loadbalancing] != 'hash'
            merged_options.delete(:hash_header)
            merged_options.delete(:hash_balance)
          end

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
