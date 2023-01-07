module VCAP::CloudController
  class RouteCreate
    class Error < StandardError
    end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    def create(message:, space:, domain:, manifest_triggered: false)
      validate_tcp_route!(domain, message)

      route = Route.new(
        host: message.host || '',
        path: message.path || '',
        port: port(message, domain),
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

      route
    rescue Sequel::ValidationFailed => e
      validation_error!(e, route.host, route.path, route.port, space, domain)
    rescue Sequel::UniqueConstraintViolation => e
      logger.warn("error creating route #{e}, retrying once")
      RouteCreate.new(user_audit_info).create(message: message, space: space, domain: domain, manifest_triggered: manifest_triggered)
    end

    private

    def validate_tcp_route!(domain, message)
      if domain.router_group_guid.present? && router_group(domain).nil?
        error!('Route could not be created because the specified domain does not have a valid router group.')
      end
    end

    def port(message, domain)
      generated_port = if !message.requested?(:port) && domain.protocols.include?('tcp')
                         PortGenerator.generate_port(domain.guid, router_group(domain).reservable_ports)
                       else
                         message.port || 0
                       end
      error!('There are no more ports available for this domain.') if generated_port < 0

      generated_port
    end

    def router_group(domain)
      @router_group ||= domain.router_group
    end

    def route_resource_manager
      @route_resource_manager ||= CloudController::DependencyLocator.instance.route_resource_manager
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

    # rubocop:todo Metrics/CyclomaticComplexity
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
        error!('Hosts are not supported for TCP routes.')
      end

      if error.errors.on(:path)&.include?(:host_and_path_domain_tcp)
        error!('Paths are not supported for TCP routes.')
      end
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    # rubocop:todo Metrics/CyclomaticComplexity
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
    # rubocop:enable Metrics/CyclomaticComplexity

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

    def logger
      @logger ||= Steno.logger('cc.action.route_create')
    end
  end
end
