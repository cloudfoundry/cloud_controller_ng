module VCAP::CloudController
  module V3
    class RouteCreate
      class << self
        def create_route(route_hash:, logger:, user_audit_info:, manifest_triggered: false)
          route = Route.create_from_hash(route_hash)

          Copilot::Adapter.create_route(route)

          Repositories::RouteEventRepository.new.record_route_create(route, user_audit_info, route_hash, manifest_triggered: manifest_triggered)

          route
        end
      end
    end
  end
end
