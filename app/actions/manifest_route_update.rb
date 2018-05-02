require 'cloud_controller/app_manifest/manifest_route'
require 'actions/v3/route_create'

module VCAP::CloudController
  class ManifestRouteUpdate
    class InvalidRoute < StandardError
    end

    class << self
      def update(app_guid, message, user_audit_info)
        return unless message.requested?(:routes)

        app = AppModel.find(guid: app_guid)
        not_found! unless app
        routes_to_map = []

        message.manifest_routes.each do |manifest_route|
          route = find_valid_route(app, manifest_route.to_hash, user_audit_info)

          if route
            routes_to_map << route
          else
            raise InvalidRoute.new("No domains exist for route #{manifest_route}")
          end
        end

        # map route to app, but do this only if the full message contains valid routes
        routes_to_map.each do |route|
          route_mapping_exists = RouteMappingModel.find(app: app, route: route)
          next if route_mapping_exists

          RouteMappingCreate.add(user_audit_info, route, app.web_process)
        end
      rescue Sequel::ValidationFailed => e
        raise InvalidRoute.new(e.message)
      end

      private

      def find_valid_route(app, manifest_route, user_audit_info)
        logger = Steno.logger('cc.action.route_update')

        manifest_route[:candidate_host_domain_pairs].each do |candidate|
          potential_domain = candidate[:domain]
          existing_domain = Domain.find(name: potential_domain)
          next if !existing_domain

          host = candidate[:host]
          route_hash = {
            host: host,
            domain_guid: existing_domain.guid,
            path: manifest_route[:path],
            port: manifest_route[:port] || 0,
            space_guid: app.space.guid
          }
          route = Route.find(host: host, domain: existing_domain, path: route_hash[:path])
          if !route
            FeatureFlag.raise_unless_enabled!(:route_creation)
            if host == '*' && existing_domain.shared?
              raise CloudController::Errors::ApiError.new_from_details('NotAuthorized')
            end
            route = V3::RouteCreate.create_route(route_hash: route_hash, user_audit_info: user_audit_info, logger: logger)
          end
          return route
        end
        nil
      end
    end
  end
end
