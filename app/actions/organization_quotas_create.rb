module VCAP::CloudController
  class OrganizationQuotasCreate
    class Error < ::StandardError
    end

    def create(message)
      org_quota = nil
      QuotaDefinition.db.transaction do
        org_quota = VCAP::CloudController::QuotaDefinition.create(
          name: message.name,
          non_basic_services_allowed: message.paid_services_allowed.nil? ? QuotaDefinition::DEFAULT_NON_BASIC_SERVICES_ALLOWED : message.paid_services_allowed,
          memory_limit: message.total_memory_in_mb || QuotaDefinition::DEFAULT_MEMORY_LIMIT,
          total_services: message.total_service_instances || QuotaDefinition::DEFAULT_TOTAL_SERVICES,
          total_routes: message.total_routes || QuotaDefinition::DEFAULT_TOTAL_ROUTES,
        )
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

    def error!(message)
      raise Error.new(message)
    end
  end
end
