module VCAP::CloudController
  module V2
    class RouteCreate
      def initialize(access_validator:, logger:)
        @access_validator = access_validator
        @logger = logger
      end

      def create_route(route_hash:)
        route = Route.db.transaction do
          r = Route.create_from_hash(route_hash)
          access_validator.validate_access(:create, r)

          r
        end

        if VCAP::CloudController::Config.kubernetes_api_configured?
          route_resource_manager.create_route(route)
        end

        route
      end

      private

      attr_reader :access_validator

      def route_resource_manager
        @route_resource_manager ||= CloudController::DependencyLocator.instance.route_resource_manager
      end
    end
  end
end
