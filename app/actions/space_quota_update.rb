module VCAP::CloudController
  class SpaceQuotaUpdate
    class Error < ::StandardError
    end

    MAX_SPACES_TO_LIST_ON_FAILURE = 2

    # rubocop:disable Metrics/CyclomaticComplexity
    def self.update(quota, message)
      if log_rate_limit(message) != QuotaDefinition::UNLIMITED
        spaces = spaces_with_unlimited_processes(quota)
        if spaces.any?
          unlimited_processes_exist_error!(spaces)
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

        quota.save
      end

      quota
    rescue Sequel::ValidationFailed => e
      if e.errors.on([:organization_id, :name])&.include?(:unique)
        raise Error.new("Space Quota '#{message.name}' already exists.")
      end

      raise Error.new(e.message)
    end
    # rubocop:enable Metrics/CyclomaticComplexity

    def self.default_if_nil(message_value, default)
      return message_value.nil? ? default : message_value
    end

    def self.memory_limit(message)
      default_if_nil(message.total_memory_in_mb, SpaceQuotaDefinition::UNLIMITED)
    end

    def self.instance_memory_limit(message)
      default_if_nil(message.per_process_memory_in_mb, SpaceQuotaDefinition::UNLIMITED)
    end

    def self.app_instance_limit(message)
      default_if_nil(message.total_instances, SpaceQuotaDefinition::UNLIMITED)
    end

    def self.app_task_limit(message)
      default_if_nil(message.per_app_tasks, SpaceQuotaDefinition::UNLIMITED)
    end

    def self.log_rate_limit(message)
      default_if_nil(message.log_rate_limit_in_bytes_per_second, SpaceQuotaDefinition::UNLIMITED)
    end

    def self.total_services(message)
      default_if_nil(message.total_service_instances, SpaceQuotaDefinition::UNLIMITED)
    end

    def self.total_service_keys(message)
      default_if_nil(message.total_service_keys, SpaceQuotaDefinition::UNLIMITED)
    end

    def self.non_basic_services_allowed(message)
      default_if_nil(message.paid_services_allowed, SpaceQuotaDefinition::DEFAULT_NON_BASIC_SERVICES_ALLOWED)
    end

    def self.total_reserved_route_ports(message)
      default_if_nil(message.total_reserved_ports, SpaceQuotaDefinition::UNLIMITED)
    end

    def self.total_routes(message)
      default_if_nil(message.total_routes, SpaceQuotaDefinition::UNLIMITED)
    end

    def self.spaces_with_unlimited_processes(quota)
      quota.spaces_dataset.
        distinct.
        select(Sequel[:spaces][:name]).
        join(:apps, space_guid: :guid).
        join(:processes, app_guid: :guid).
        where(log_rate_limit: QuotaDefinition::UNLIMITED).
        order(:name).
        all
    end

    def self.unlimited_processes_exist_error!(spaces)
      named_spaces = spaces.take(MAX_SPACES_TO_LIST_ON_FAILURE).map(&:name).join("', '")
      message = 'This quota is applied to ' +
        if spaces.size == 1
          "space '#{named_spaces}' which contains"
        elsif spaces.size > MAX_SPACES_TO_LIST_ON_FAILURE
          "spaces '#{named_spaces}' and #{spaces.drop(MAX_SPACES_TO_LIST_ON_FAILURE).size}" \
          ' other spaces which contain'
        else
          "spaces '#{named_spaces}' which contain"
        end + ' apps running with an unlimited log rate limit.'

      raise Error.new("Current usage exceeds new quota values. #{message}")
    end

    private_class_method :spaces_with_unlimited_processes,
                         :unlimited_processes_exist_error!
  end
end
