module VCAP::CloudController
  class RouteCreate
    class Error < StandardError
    end

    def create(message:, space:, domain:)
      route = Route.new(
        host: message.host || '',
        space_guid: message.space_guid,
        domain_guid: message.domain_guid
      )

      Route.db.transaction do
        route.save
      end

      route
    rescue Sequel::ValidationFailed => e
      validation_error!(e, route.host, space, domain)
    end

    private

    def validation_error!(error, host, space, domain)
      if error.errors.on(:domain)&.include?(:invalid_relation)
        error!("Invalid domain. Domain '#{domain.name}' is not available in organization '#{space.organization.name}'.")
      end

      if error.errors.on([:host, :domain_id])&.include?(:unique)
        if host.empty?
          error!("Route already exists for domain '#{domain.name}'.")
        else
          error!("Route already exists with host '#{host}' for domain '#{domain.name}'.")
        end
      end

      if error.errors.on(:space)&.include?(:total_routes_exceeded)
        error!("Routes quota exceeded for space '#{space.name}'.")
      end

      if error.errors.on(:organization)&.include?(:total_routes_exceeded)
        error!("Routes quota exceeded for organization '#{space.organization.name}'.")
      end

      if error.errors.on(:host)&.include?(:domain_conflict)
        error!("Route conflicts with domain '#{host}.#{domain.name}'.")
      end

      if error.errors.on(:host)&.include?(:system_hostname_conflict)
        error!('Route conflicts with a reserved system route.')
      end

      if error.errors.on(:host)&.include?(:wildcard_host_not_supported_for_internal_domain)
        error!('Wildcard hosts are not supported for internal domains.')
      end

      if error.errors.on(:host)&.include?('is required for shared-domains')
        error!('Missing host. Routes in shared domains must have a host defined.')
      end

      error!(error.message)
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
