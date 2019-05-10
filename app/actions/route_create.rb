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
      validation_error!(e, space, domain)
    end

    private

    def validation_error!(error, space, domain)
      if error.errors.on(:domain)&.include?(:invalid_relation)
        error!("Invalid domain. Domain '#{domain.name}' is not available in organization '#{space.organization.name}'.")
      end

      if error.errors.on([:host, :domain_id])&.include?(:unique)
        error!("Route already exists for domain '#{domain.name}'.")
      end

      if error.errors.on(:space)&.include?(:total_routes_exceeded)
        error!("Routes quota exceeded for space '#{space.name}'.")
      end

      if error.errors.on(:organization)&.include?(:total_routes_exceeded)
        error!("Routes quota exceeded for organization '#{space.organization.name}'.")
      end

      error!(error.message)
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
