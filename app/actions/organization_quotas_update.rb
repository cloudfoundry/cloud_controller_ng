module VCAP::CloudController
  class OrganizationQuotasUpdate
    class Error < ::StandardError
    end

    # rubocop:disable Metrics/CyclomaticComplexity
    def self.update(quota, message)
      quota.db.transaction do
        quota.lock!

        quota.name = message.name if message.name

        quota.memory_limit = message.total_memory_in_mb if message.total_memory_in_mb

        quota.instance_memory_limit = message.per_process_memory_in_mb if message.per_process_memory_in_mb
        quota.app_instance_limit = message.total_instances if message.total_instances
        quota.app_task_limit = message.per_app_tasks if message.per_app_tasks

        quota.total_services = message.total_service_instances if message.total_service_instances
        quota.total_service_keys = message.total_service_keys if message.total_service_keys
        quota.non_basic_services_allowed = message.paid_services_allowed if message.paid_services_allowed

        quota.total_reserved_route_ports = message.total_reserved_ports if message.total_reserved_ports
        quota.total_routes = message.total_routes if message.total_routes

        quota.total_private_domains = message.total_domains if message.total_domains

        quota.save
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      quota
    rescue Sequel::ValidationFailed => e
      if e.errors.on(:name)&.include?(:unique)
        raise Error.new("Organization Quota '#{message.name}' already exists.")
      end

      raise Error.new(e.message)
    end
  end
end
