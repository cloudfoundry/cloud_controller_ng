require 'cloud_controller/app_manifest/manifest_route'
require 'actions/route_create'
require 'actions/route_update'

module VCAP::CloudController
  class ManifestRouteUpdate
    class InvalidRoute < StandardError
    end

    # This log fires when the class is loaded - if you don't see it, the new code isn't being loaded
    Steno.logger('cc.action.manifest_route_update').error("CRITICAL: ManifestRouteUpdate class loaded at #{Time.now}")

    class << self
      def update(app_guid, message, user_audit_info)
        logger = Steno.logger('cc.action.manifest_route_update')
        logger.error("CRITICAL: ManifestRouteUpdate.update called", app_guid: app_guid, message: message.inspect, message_routes: message.routes.inspect, location: "#{__FILE__}:#{__LINE__}")

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
            protocol: manifest_route_mapping[:protocol]
          }

          raise InvalidRoute.new("No domains exist for route #{manifest_route_mapping[:route]}") if route[:model].blank?

          routes_to_map << route
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
      rescue Sequel::ValidationFailed, RouteCreate::Error, RouteUpdate::Error => e
        raise InvalidRoute.new(e.message)
      end

      private

      def find_or_create_valid_route(app, manifest_route, user_audit_info)
        logger = Steno.logger('cc.action.manifest_route_update')
        logger.error("CRITICAL: find_or_create_valid_route called", manifest_route: manifest_route.inspect, has_options: manifest_route[:options].present?, options_value: manifest_route[:options].inspect, location: "#{__FILE__}:#{__LINE__}")

        manifest_route[:candidate_host_domain_pairs].each do |candidate|
          potential_domain = candidate[:domain]
          existing_domain = Domain.find(name: potential_domain)
          next unless existing_domain

          host = candidate[:host]

          route = Route.find(
            host: host,
            domain: existing_domain,
            **manifest_route.compact.slice(
              :path,
              :port
            )
          )

          logger = Steno.logger('cc.action.manifest_route_update')
          logger.error("CRITICAL: Route lookup completed", manifest_route: manifest_route.inspect, route_found: !route.nil?, route_guid: route&.guid, route_options: route&.options.inspect, manifest_options: manifest_route[:options].inspect, manifest_options_present: manifest_route[:options].present?, location: "#{__FILE__}:#{__LINE__}")

          if !route
            logger.error("CRITICAL: Creating new route (route is nil)", location: "#{__FILE__}:#{__LINE__}")
            FeatureFlag.raise_unless_enabled!(:route_creation)
            raise CloudController::Errors::ApiError.new_from_details('NotAuthorized') if host == '*' && existing_domain.shared?

            message = RouteCreateMessage.new({
                                               'host' => host,
                                               'path' => manifest_route[:path],
                                               'port' => manifest_route[:port],
                                               'options' => manifest_route[:options]
                                             })

            route = RouteCreate.new(user_audit_info).create(
              message: message,
              space: app.space,
              domain: existing_domain,
              manifest_triggered: true
            )
          elsif !route.available_in_space?(app.space)
            logger.error("CRITICAL: Route not available in space", location: "#{__FILE__}:#{__LINE__}")
            raise InvalidRoute.new('Routes cannot be mapped to destinations in different spaces')
          elsif manifest_route[:options]
            logger.error("CRITICAL: Updating existing route options - ENTERING THIS BRANCH", existing_options: route.options.inspect, manifest_options: manifest_route[:options].inspect, location: "#{__FILE__}:#{__LINE__}")
            # remove nil values from options
            manifest_route[:options] = manifest_route[:options].compact
            logger.error("CRITICAL: About to call RouteUpdate.new.update", manifest_route_options: manifest_route[:options].inspect, location: "#{__FILE__}:#{__LINE__}")
            message = RouteUpdateMessage.new({
                                               'options' => manifest_route[:options]
                                             })
            logger.error("CRITICAL: Created RouteUpdateMessage", message: message.inspect, message_options: message.options.inspect, location: "#{__FILE__}:#{__LINE__}")
            route = RouteUpdate.new.update(route:, message:)
            logger.error("CRITICAL: RouteUpdate.new.update completed", updated_route_options: route.options.inspect, location: "#{__FILE__}:#{__LINE__}")
          else
            logger.error("CRITICAL: Route exists, no update needed - ELSE BRANCH", route_has_options: route.options.present?, manifest_has_options: manifest_route[:options].present?, route_options: route.options.inspect, manifest_options: manifest_route[:options].inspect, location: "#{__FILE__}:#{__LINE__}")
          end

          return route
        end
        nil
      end
    end
  end
end
