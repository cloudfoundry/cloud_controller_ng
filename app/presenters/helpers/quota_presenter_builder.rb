module VCAP::CloudController::Presenters
  class QuotaPresenterBuilder
    def initialize(quota)
      @quota = quota
      @hash = {}
    end

    def build
      @hash
    end

    def add_resource_limits
      @hash.merge!({
                     apps: {
                       total_memory_in_mb: unlimited_to_nil(@quota.memory_limit),
                       per_process_memory_in_mb: unlimited_to_nil(@quota.instance_memory_limit),
                       total_instances: unlimited_to_nil(@quota.app_instance_limit),
                       per_app_tasks: unlimited_to_nil(@quota.app_task_limit),
                       log_rate_limit_in_bytes_per_second: unlimited_to_nil(@quota.log_rate_limit)
                     },
                     services: {
                       paid_services_allowed: @quota.non_basic_services_allowed,
                       total_service_instances: unlimited_to_nil(@quota.total_services),
                       total_service_keys: unlimited_to_nil(@quota.total_service_keys)
                     },
                     routes: {
                       total_routes: unlimited_to_nil(@quota.total_routes),
                       total_reserved_ports: unlimited_to_nil(@quota.total_reserved_route_ports)
                     }
                   })

      if @quota.respond_to?(:guid)
        @hash[:guid] = @quota.guid
        @hash[:created_at] = @quota.created_at
        @hash[:updated_at] = @quota.updated_at
        @hash[:name] = @quota.name
      end
      self
    end

    def add_domains
      @hash[:domains] = {
        total_domains: unlimited_to_nil(@quota.total_private_domains)
      }
      self
    end

    def add_relationships(relationships)
      @hash[:relationships] = relationships
      self
    end

    def add_links(links)
      @hash[:links] = links
      self
    end

    private

    def unlimited_to_nil(value)
      value == -1 ? nil : value
    end
  end
end
