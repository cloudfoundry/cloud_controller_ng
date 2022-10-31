require 'cloud_controller/app_manifest/manifest_route'
require 'actions/route_create'

module VCAP::CloudController
  class ManifestRouteUpdate
    class InvalidRoute < StandardError
    end

    class << self
      def update(app_guid, message, user_audit_info)
        return unless message.requested?(:routes)

        app = AppModel.find(guid: app_guid)
        not_found! unless app

        apps_hash = {
          app_guid => app
        }
        routes_to_map = []

        message.manifest_route_mappings.each do |manifest_route_mapping|
          route = {
            model: find_or_create_valid_route(app, manifest_route_mapping[:route].to_hash, user_audit_info),
            protocol: manifest_route_mapping[:protocol],
          }

          if route[:model].present?
            routes_to_map << route
          else
            raise InvalidRoute.new("No domains exist for route #{manifest_route_mapping[:route]}")
          end
        end

        # map route to app, but do this only if the full message contains valid routes
        routes_to_map.
          each do |route|
            route_mapping = RouteMappingModel.find(app: app, route: route[:model])
            if route_mapping.nil?
              UpdateRouteDestinations.add(
                [{ app_guid: app_guid, process_type: 'web', protocol: route[:protocol] }],
                route[:model],
                apps_hash,
                user_audit_info,
                manifest_triggered: true
              )
            elsif !route[:protocol].nil? && route[:protocol] != route_mapping.protocol
              UpdateRouteDestinations.replace(
                [{ app_guid: app_guid, process_type: 'web', protocol: route[:protocol] }],
                route[:model],
                apps_hash,
                user_audit_info,
                manifest_triggered: true
              )
            end
          end
      rescue Sequel::ValidationFailed, RouteCreate::Error => e
        raise InvalidRoute.new(e.message)
      end

      private

      def find_or_create_valid_route(app, manifest_route, user_audit_info)
        manifest_route[:candidate_host_domain_pairs].each do |candidate|
          potential_domain = candidate[:domain]
          existing_domain = Domain.find(name: potential_domain)
          next if !existing_domain

          host = candidate[:host]

          route = Route.find(
            host: host,
            domain: existing_domain,
            **manifest_route.compact.slice(
              :path,
              :port,
            )
          )

          if !route
            FeatureFlag.raise_unless_enabled!(:route_creation)
            if host == '*' && existing_domain.shared?
              raise CloudController::Errors::ApiError.new_from_details('NotAuthorized')
            end

            message = RouteCreateMessage.new({
              'host' => host,
              'path' => manifest_route[:path],
              'port' => manifest_route[:port],
            })

            route = RouteCreate.new(user_audit_info).create(
              message: message,
              space: app.space,
              domain: existing_domain,
              manifest_triggered: true,
            )
          elsif route.space.guid != app.space_guid
            raise InvalidRoute.new('Routes cannot be mapped to destinations in different spaces')
          end

          return route
        end
        nil
      end
    end
  end
end
