module VCAP::CloudController
  class RouteUpdate
    class Error < StandardError
    end

    def update(route:, message:)
      Route.db.transaction do
        route.options = route.options.symbolize_keys.merge(message.options) if message.requested?(:options)
        route.save
        MetadataUpdate.update(route, message)
      end

      if message.requested?(:options)
        route.apps.each do |process|
          ProcessRouteHandler.new(process).notify_backend_of_route_update
        end
      end
      route
    rescue Sequel::ValidationFailed => e
      validation_error!(e)
    end

    private

    def validation_error!(error)
      # Handle hash_header validation error for hash loadbalancing
      raise Error.new('Hash header must be present when loadbalancing is set to hash.') if error.errors.on(:route)&.include?(:hash_header_missing)

      # Handle route options size exceeded error
      if error.errors.on(:route)&.include?(:options_size_exceeded)
        max_size = Config.config.get(:max_route_options_size)
        raise Error.new("Route options size exceeded: options must be smaller than #{max_size} bytes.")
      end

      # Fallback for any other validation errors
      raise Error.new(error.message)
    end
  end
end
