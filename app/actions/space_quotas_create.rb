module VCAP::CloudController
  class SpaceQuotasCreate
    class Error < ::StandardError
    end

    # rubocop:todo Metrics/CyclomaticComplexity
    def create(message, organization:)
      space_quota = nil

      SpaceQuotaDefinition.db.transaction do
        space_quota = VCAP::CloudController::SpaceQuotaDefinition.create(
          name: message.name,
          organization: organization,

          # Apps
          memory_limit: message.total_memory_in_mb || SpaceQuotaDefinition::DEFAULT_MEMORY_LIMIT,
          instance_memory_limit: message.per_process_memory_in_mb || SpaceQuotaDefinition::UNLIMITED,
          app_instance_limit: message.total_instances || SpaceQuotaDefinition::UNLIMITED,
          app_task_limit: message.per_app_tasks || SpaceQuotaDefinition::UNLIMITED,
          log_rate_limit: message.log_rate_limit_in_bytes_per_second || QuotaDefinition::UNLIMITED,

          # Services
          total_services: message.total_service_instances || SpaceQuotaDefinition::DEFAULT_TOTAL_SERVICES,
          total_service_keys: message.total_service_keys || SpaceQuotaDefinition::UNLIMITED,
          non_basic_services_allowed: message.paid_services_allowed.nil? ? SpaceQuotaDefinition::DEFAULT_NON_BASIC_SERVICES_ALLOWED : message.paid_services_allowed,

          # Routes
          total_routes: message.total_routes || SpaceQuotaDefinition::DEFAULT_TOTAL_ROUTES,
          total_reserved_route_ports: message.total_reserved_ports || SpaceQuotaDefinition::UNLIMITED,
        )

        spaces = valid_spaces(message.space_guids, organization)
        spaces.each { |space| space_quota.add_space(space) }
      end

      space_quota
    rescue Sequel::ValidationFailed => e
      validation_error!(e, message)
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    private

    def validation_error!(error, message)
      if error.errors.on([:organization_id, :name])&.include?(:unique)
        error!("Space Quota '#{message.name}' already exists.")
      end

      error!(error.message)
    end

    def valid_spaces(space_guids, organization)
      spaces = Space.filter(organization_id: organization.id).where(guid: space_guids).all
      return spaces if spaces.length == space_guids.length

      invalid_space_guids = space_guids - spaces.map(&:guid)
      error!("Spaces with guids #{invalid_space_guids} do not exist within the organization specified, or you do not have access to them.")
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
