module VCAP::CloudController
  class BaseQuotaSummaryFetcher
    def self.fetch(resource)
      new(resource).fetch
    end

    def initialize(resource)
      @resource = resource
    end

    def fetch
      {
        apps: {
          total_memory_in_mb: {
            limit: memory_limit,
            used: @resource.memory_used,
            available: memory_limit - @resource.memory_used
          },
          # per_process_memory_in_mb: {
          #   limit: instance_memory_limit
          # },
          total_instances: {
            limit: app_instance_limit,
            used: @resource.total_instances_used,
            available: app_instance_limit - @resource.total_instances_used
          },
          # per_app_tasks: {
          #   limit: app_tasks_limit
          # }
        },
        services: {
          # paid_services_allowed: {
          #   limit: paid_services_allowed
          # },
          total_service_instances: {
            limit: service_instances_limit,
            used: @resource.service_instances.count,
            available: service_instances_limit - @resource.service_instances.count
          },
          total_service_keys: {
            limit: service_keys_limit,
            used: @resource.number_service_keys,
            available: service_keys_limit - @resource.number_service_keys
          }
        },
        routes: {
          total_routes: {
            limit: routes_limit,
            used: @resource.routes.count,
            available: routes_limit - @resource.routes.count
          },
          total_reserved_ports: {
            limit: reserved_route_ports_limit,
            used: @resource.total_reserved_ports_used,
            available: reserved_route_ports_limit - @resource.total_reserved_ports_used
          }
        }
      }
    end

    private

    def memory_limit
      raise NotImplementedError
    end

    def memory_available
      raise NotImplementedError
    end

    def instance_memory_limit
      raise NotImplementedError
    end

    def app_instance_limit
      raise NotImplementedError
    end

    def app_tasks_limit
      raise NotImplementedError
    end

    # def paid_services_allowed
    #   raise NotImplementedError
    # end

    def service_instances_limit
      raise NotImplementedError
    end

    def service_keys_limit
      raise NotImplementedError
    end

    def routes_limit
      raise NotImplementedError
    end

    def total_reserved_ports_used
      raise NotImplementedError
    end

    def reserved_route_ports_limit
      raise NotImplementedError
    end
  end
end

