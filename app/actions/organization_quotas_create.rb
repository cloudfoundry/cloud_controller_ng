module VCAP::CloudController
  class OrganizationQuotasCreate
    class Error < ::StandardError
    end

    # rubocop:todo Metrics/CyclomaticComplexity
    def create(message)
      org_quota = nil

      QuotaDefinition.db.transaction do
        org_quota = VCAP::CloudController::QuotaDefinition.create(
          name: message.name,

          # Apps
          memory_limit: message.total_memory_in_mb || QuotaDefinition::DEFAULT_MEMORY_LIMIT,
          instance_memory_limit: message.per_process_memory_in_mb || QuotaDefinition::UNLIMITED,
          app_instance_limit: message.total_instances || QuotaDefinition::UNLIMITED,
          app_task_limit: message.per_app_tasks || QuotaDefinition::UNLIMITED,
          log_rate_limit: message.log_rate_limit_in_bytes_per_second || QuotaDefinition::UNLIMITED,

          # Services
          total_services: message.total_service_instances || QuotaDefinition::DEFAULT_TOTAL_SERVICES,
          total_service_keys: message.total_service_keys || QuotaDefinition::UNLIMITED,
          non_basic_services_allowed: message.paid_services_allowed.nil? ? QuotaDefinition::DEFAULT_NON_BASIC_SERVICES_ALLOWED : message.paid_services_allowed,

          # Routes
          total_routes: message.total_routes || QuotaDefinition::DEFAULT_TOTAL_ROUTES,
          total_reserved_route_ports: message.total_reserved_ports || QuotaDefinition::UNLIMITED,

          # Domains
          total_private_domains: message.total_domains || QuotaDefinition::UNLIMITED,
        )

        orgs = valid_orgs(message.organization_guids)
        orgs.each { |org| org_quota.add_organization(org) }
      end
      org_quota
    rescue Sequel::ValidationFailed => e
      validation_error!(e, message)
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    private

    def validation_error!(error, message)
      if error.errors.on(:name)&.include?(:unique)
        error!("Organization Quota '#{message.name}' already exists.")
      end

      error!(error.message)
    end

    def valid_orgs(org_guids)
      orgs = Organization.where(guid: org_guids).all
      return orgs if orgs.length == org_guids.length

      invalid_org_guids = org_guids - orgs.map(&:guid)
      error!("Organizations with guids #{invalid_org_guids} do not exist, or you do not have access to them.")
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
