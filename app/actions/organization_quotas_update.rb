module VCAP::CloudController
  class OrganizationQuotasUpdate
    class Error < ::StandardError
    end

    MAX_ORGS_TO_LIST_ON_FAILURE = 2

    # rubocop:disable Metrics/CyclomaticComplexity
    def self.update(quota, message)
      if log_rate_limit(message) != QuotaDefinition::UNLIMITED
        orgs = orgs_with_unlimited_processes(quota)
        if orgs.any?
          unlimited_processes_exist_error!(orgs)
        end
      end

      quota.db.transaction do
        quota.lock!

        quota.name = message.name if message.requested? :name

        quota.memory_limit = memory_limit(message) if message.apps_limits_message.requested? :total_memory_in_mb
        quota.instance_memory_limit = instance_memory_limit(message) if message.apps_limits_message.requested? :per_process_memory_in_mb
        quota.app_instance_limit = app_instance_limit(message) if message.apps_limits_message.requested? :total_instances
        quota.app_task_limit = app_task_limit(message) if message.apps_limits_message.requested? :per_app_tasks
        quota.log_rate_limit = log_rate_limit(message) if message.apps_limits_message.requested? :log_rate_limit_in_bytes_per_second

        quota.total_services = total_services(message) if message.services_limits_message.requested? :total_service_instances
        quota.total_service_keys = total_service_keys(message) if message.services_limits_message.requested? :total_service_keys
        quota.non_basic_services_allowed = non_basic_services_allowed(message) if message.services_limits_message.requested? :paid_services_allowed

        quota.total_reserved_route_ports = total_reserved_route_ports(message) if message.routes_limits_message.requested? :total_reserved_ports
        quota.total_routes = total_routes(message) if message.routes_limits_message.requested? :total_routes

        quota.total_private_domains = total_private_domains(message) if message.domains_limits_message.requested? :total_domains

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

    def self.default_if_nil(message_value, default)
      return message_value.nil? ? default : message_value
    end

    def self.memory_limit(message)
      default_if_nil(message.total_memory_in_mb, QuotaDefinition::UNLIMITED)
    end

    def self.instance_memory_limit(message)
      default_if_nil(message.per_process_memory_in_mb, QuotaDefinition::UNLIMITED)
    end

    def self.app_instance_limit(message)
      default_if_nil(message.total_instances, QuotaDefinition::UNLIMITED)
    end

    def self.app_task_limit(message)
      default_if_nil(message.per_app_tasks, QuotaDefinition::UNLIMITED)
    end

    def self.log_rate_limit(message)
      default_if_nil(message.log_rate_limit_in_bytes_per_second, QuotaDefinition::UNLIMITED)
    end

    def self.total_services(message)
      default_if_nil(message.total_service_instances, QuotaDefinition::UNLIMITED)
    end

    def self.total_service_keys(message)
      default_if_nil(message.total_service_keys, QuotaDefinition::UNLIMITED)
    end

    def self.non_basic_services_allowed(message)
      default_if_nil(message.paid_services_allowed, QuotaDefinition::DEFAULT_NON_BASIC_SERVICES_ALLOWED)
    end

    def self.total_reserved_route_ports(message)
      default_if_nil(message.total_reserved_ports, QuotaDefinition::UNLIMITED)
    end

    def self.total_routes(message)
      default_if_nil(message.total_routes, QuotaDefinition::UNLIMITED)
    end

    def self.total_private_domains(message)
      default_if_nil(message.total_domains, QuotaDefinition::UNLIMITED)
    end

    def self.orgs_with_unlimited_processes(quota)
      quota.organizations_dataset.
        distinct.
        select(Sequel[:organizations][:name]).
        join(:spaces, organization_id: :id).
        join(:apps, space_guid: :guid).
        join(:processes, app_guid: :guid).
        where(log_rate_limit: QuotaDefinition::UNLIMITED).
        order(:name).
        all
    end

    def self.unlimited_processes_exist_error!(orgs)
      named_orgs = orgs.take(MAX_ORGS_TO_LIST_ON_FAILURE).map(&:name).join("', '")
      message = 'This quota is applied to ' +
        if orgs.size == 1
          "org '#{named_orgs}' which contains"
        elsif orgs.size > MAX_ORGS_TO_LIST_ON_FAILURE
          "orgs '#{named_orgs}' and #{orgs.drop(MAX_ORGS_TO_LIST_ON_FAILURE).size}" \
          ' other orgs which contain'
        else
          "orgs '#{named_orgs}' which contain"
        end + ' apps running with an unlimited log rate limit.'

      raise Error.new("Current usage exceeds new quota values. #{message}")
    end

    private_class_method :orgs_with_unlimited_processes,
                         :unlimited_processes_exist_error!
  end
end
