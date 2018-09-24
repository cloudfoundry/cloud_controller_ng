module VCAP::CloudController
  module V2
    class RouteCreate
      def initialize(access_validator:, logger:)
        @access_validator = access_validator
        @logger = logger
      end

      def create_route(route_hash:)
        Route.db.transaction do
          route = Route.create_from_hash(route_hash)
          @access_validator.validate_access(:create, route)

          Copilot::Adapter.create_route(route) if Config.config.get(:copilot, :enabled)

          route
        end
      end
    end
  end
end
