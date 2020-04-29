module VCAP::CloudController
  module V3
    class RouteCreate
      class << self
        def create_route(route_hash:, logger:, user_audit_info:, manifest_triggered: false)
          route = Route.create_from_hash(route_hash)
          if VCAP::CloudController::Config.kubernetes_api_configured?
            client = route_crd_client
            client.create_route(route)
          end

          Repositories::RouteEventRepository.new.record_route_create(route, user_audit_info, route_hash, manifest_triggered: manifest_triggered)

          route
        end

        def route_crd_client
          CloudController::DependencyLocator.instance.route_crd_client
        end
      end
    end
  end
end
