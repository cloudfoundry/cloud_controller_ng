module VCAP::CloudController
  class RouteUpdate
    class Error < StandardError
    end

    def update(route:, message:)
      logger = Steno.logger('cc.action.route_update')
      logger.info("RouteUpdate.update called", route_guid: route.guid, route_options: route.options.inspect, message: message.inspect, message_options: message.options.inspect, message_requested_options: message.requested?(:options), location: "#{__FILE__}:#{__LINE__}")

      Route.db.transaction do
        if message.requested?(:options)
          # Merge existing options with new options from message
          existing_options = route.options&.deep_symbolize_keys || {}
          merged_options = existing_options.merge(message.options).compact

          # Set the options on the route (cleanup is handled by model)
          route.options = merged_options
        end

        logger.info("About to call route.save", route_guid: route.guid, route_options: route.options.inspect, raise_on_failure: true, location: "#{__FILE__}:#{__LINE__}")

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

    def validation_error!(error, route)
      # Handle hash_header validation error for hash loadbalancing
      if error.errors.on(:route)&.include?(:hash_header_missing)
        raise Error.new('Hash header must be present when loadbalancing is set to hash')
      end

      # Fallback for any other validation errors
      raise Error.new(error.message)
    end
  end
end
