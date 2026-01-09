module VCAP::CloudController
  class RouteUpdate
    class Error < StandardError
    end

    def update(route:, message:)

      Route.db.transaction do
        route.options = route.options.symbolize_keys.merge(message.options).compact if message.requested?(:options)
        route.save(raise_on_failure: true)
        MetadataUpdate.update(route, message)
      end

      if message.requested?(:options)
        route.apps.each do |process|
          ProcessRouteHandler.new(process).notify_backend_of_route_update
        end
      end
      route
    rescue Sequel::ValidationFailed => e
      validation_error!(e, route)
    end

    private

    def validation_error!(error)
      # Handle hash_header validation error for hash loadbalancing
      if error.errors.on(:route)&.include?(:hash_header_missing)
        raise Error.new('Hash header must be present when loadbalancing is set to hash')
      end

      # Fallback for any other validation errors
      raise Error.new(error.message)
    end
  end
end
