module VCAP::CloudController
  class OrganizationQuotasCreate
    class Error < ::StandardError
    end

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

          # Services
          total_services: message.total_service_instances || QuotaDefinition::DEFAULT_TOTAL_SERVICES,
          total_service_keys: message.total_service_keys || QuotaDefinition::UNLIMITED,
          non_basic_services_allowed: message.paid_services_allowed.nil? ?
            QuotaDefinition::DEFAULT_NON_BASIC_SERVICES_ALLOWED : message.paid_services_allowed,

          # Routes
          total_routes: QuotaDefinition::DEFAULT_TOTAL_ROUTES,
        )

        message.organization_guids.each do |guid|
          org = organization_guid_validation(guid)
          org_quota.add_organization(org)
        end
      end
      org_quota
    rescue Sequel::ValidationFailed => e
      validation_error!(e, message)
    end

    private

    def validation_error!(error, message)
      if error.errors.on(:name)&.include?(:unique)
        error!("Organization Quota '#{message.name}' already exists.")
      end

      error!(error.message)
    end

    def organization_guid_validation(guid)
      org = Organization.first(guid: guid)
      if !org
        error!("Organization with guid '#{guid}' does not exist, or you do not have access to it.")
      end
      org
    end

    def error!(message)
      raise Error.new(message)
    end
  end
end
