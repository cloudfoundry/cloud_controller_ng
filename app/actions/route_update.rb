require 'cloud_controller/app_manifest/route_domain_splitter'

module VCAP::CloudController
  class RouteUpdate
    class InvalidRoute < StandardError; end

    attr_reader :user_audit_info

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def update(app_guid, message)
      return unless message.requested?(:routes)

      app = AppModel.find(guid: app_guid)
      not_found! unless app
      routes_to_map = []

      message.routes.each do |route_hash|
        route_url = route_hash[:route]
        route = find_valid_route_in_url(app, route_url)

        if route
          routes_to_map << route
        else
          raise RouteValidator::RouteInvalid.new("no domains exist for route #{route_url}")
        end
      end

      # map route to app, but do this only if the full message contains valid routes
      routes_to_map.each do |route|
        rm = RouteMappingModel.find(app: app, route: route)
        next if rm

        RouteMappingCreate.add(user_audit_info, route, app.web_process)
      end
    rescue Sequel::ValidationFailed => e
      raise InvalidRoute.new(e.message)
    end

    # All access should have been determined in the message parser/validator,
    # not here in manifest actions.
    def validate_access(*_)
      true
    end

    private

    def find_valid_route_in_url(app, route_url)
      route_components = RouteDomainSplitter.split(route_url)
      potential_host = route_components[:potential_host]

      route_components[:potential_domains].each do |potential_domain|
        existing_domain = Domain.find(name: potential_domain)
        next if !existing_domain

        # the part before the matched domain is considered the host
        host = (potential_host.split('.') - potential_domain.split('.')).join('.')

        route_hash = {
          host: host,
          domain_guid: existing_domain.guid,
          path: route_components[:path],
          space_guid: app.space.guid
        }
        route = Route.find(host: host, domain: existing_domain, path: route_components[:path])
        if !route
          route = RouteCreate.new(access_validator: self, logger: logger).create_route(route_hash: route_hash)
          Repositories::RouteEventRepository.new.record_route_create(route, user_audit_info, route_hash)
        end
        return route
      end
      nil
    end

    def logger
      @logger ||= Steno.logger('cc.action.route_update')
    end
  end
end
