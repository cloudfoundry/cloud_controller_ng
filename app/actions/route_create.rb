module VCAP::CloudController
  class RouteCreate
    class Error < StandardError
    end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def create(message:, space:, domain:, manifest_triggered: false)
      route = Route.new(
        host: message.host || '',
        path: message.path || '',
        port: message.port || 0,
        space: space,
        domain: domain,
      )

      Route.db.transaction do
        route.save

        MetadataUpdate.update(route, message)
      end

      Repositories::RouteEventRepository.new.record_route_create(
        route,
        @user_audit_info,
        message.audit_hash,
        manifest_triggered: manifest_triggered,
      )

      if VCAP::CloudController::Config.kubernetes_api_configured?
        route_crd_client.create_route(route)
      end

      route
    rescue Sequel::ValidationFailed => e
      validation_error!(e, route.host, route.path, route.port, space, domain)
    end

    private

    def route_crd_client
      @route_crd_client ||= CloudController::DependencyLocator.instance.route_crd_client
    end

    def validation_error!(error, host, path, port, space, domain)
      if error.errors.on(:domain)&.include?(:invalid_relation)
        error!("Invalid domain. Domain '#{domain.name}' is not available in organization '#{space.organization.name}'.")
      end

      if error.errors.on(:space)&.include?(:total_routes_exceeded)
        error!("Routes quota exceeded for space '#{space.name}'.")
      end

      if error.errors.on(:space)&.include?(:total_reserved_route_ports_exceeded)
        error!("Reserved route ports quota exceeded for space '#{space.name}'.")
      end

      if error.errors.on(:organization)&.include?(:total_routes_exceeded)
        error!("Routes quota exceeded for organization '#{space.organization.name}'.")
      end

      if error.errors.on(:organization)&.include?(:total_reserved_route_ports_exceeded)
        error!("Reserved route ports quota exceeded for organization '#{space.organization.name}'.")
      end

      validation_error_routing_api!(error)
      validation_error_host!(error, host, domain)
      validation_error_path!(error, host, path, domain)
      validation_error_port!(error, host, port, domain)

      error!(error.message)
    end

    def validation_error_routing_api!(error)
      if error.errors.on(:routing_api)&.include?(:uaa_unavailable)
        raise RoutingApi::UaaUnavailable
      end

      if error.errors.on(:routing_api)&.include?(:routing_api_unavailable)
        raise RoutingApi::RoutingApiUnavailable
      end

      if error.errors.on(:routing_api)&.include?(:routing_api_disabled)
        raise RoutingApi::RoutingApiDisabled
      end
    end

    def validation_error_host!(error, host, domain)
      if error.errors.on(:host)&.include?(:domain_conflict)
        error!("Route conflicts with domain '#{host}.#{domain.name}'.")
      end

      if error.errors.on(:host)&.include?(:system_hostname_conflict)
        error!('Route conflicts with a reserved system route.')
      end

      if error.errors.on(:host)&.include?(:format)
        error!('Host format is invalid.')
      end

      if error.errors.on(:host)&.include?(:wildcard_host_not_supported_for_internal_domain)
        error!('Wildcard hosts are not supported for internal domains.')
      end

      if error.errors.on(:host)&.include?('is required for shared-domains')
        error!('Missing host. Routes in shared domains must have a host defined.')
      end

      if error.errors.on(:host)&.include?('combined with domain name must be no more than 253 characters')
        error!('Host combined with domain name must be no more than 253 characters.')
      end

      if error.errors.on([:host, :domain_id])&.include?(:unique)
        if host.empty?
          error!("Route already exists for domain '#{domain.name}'.")
        else
          error!("Route already exists with host '#{host}' for domain '#{domain.name}'.")
        end
      end

      if error.errors.on(:host)&.include?(:host_and_path_domain_tcp)
        error!("Routes with protocol 'tcp' do not support paths or hosts.")
      end
    end

    def validation_error_path!(error, host, path, domain)
      if error.errors.on(:path)&.include?(:path_not_supported_for_internal_domain)
        error!('Paths are not supported for internal domains.')
      end

      if error.errors.on(:path)&.include?(:invalid_path)
        error!('Path is invalid.')
      end

      if error.errors.on(:path)&.include?(:path_exceeds_valid_length)
        error!('Path exceeds 128 characters.')
      end

      if error.errors.on(:path)&.include?(:single_slash)
        error!("Path cannot be a single '/'.")
      end

      if error.errors.on(:path)&.include?(:missing_beginning_slash)
        error!("Path is missing the beginning '/'.")
      end

      if error.errors.on(:path)&.include?(:path_contains_question)
        error!("Path cannot contain '?'.")
      end
      if error.errors.on([:host, :domain_id, :path])&.include?(:unique)
        if host.empty?
          error!("Route already exists with path '#{path}' for domain '#{domain.name}'.")
        else
          error!("Route already exists with host '#{host}' and path '#{path}' for domain '#{domain.name}'.")
        end
      end
    end

    def validation_error_port!(error, host, port, domain)
      if error.errors.on(:port)&.include?(:port_required)
        error!("Routes with protocol 'tcp' must specify a port.")
      end

      if error.errors.on(:port)&.include?(:port_unavailable)
        error!("Port '#{port}' is not available. Try a different port or use a different domain.")
      end

      if error.errors.on([:host, :domain_id, :port])&.include?(:unique)
        error!("Route already exists with port '#{port}' for domain '#{domain.name}'.")
      end

      if error.errors.on(:port)&.include?(:port_taken)
        error!("Port '#{port}' is not available. Try a different port or use a different domain.")
      end

      if error.errors.on(:port)&.include?(:port_unsupported)
        error!("Routes with protocol 'http' do not support ports.")
      end
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
