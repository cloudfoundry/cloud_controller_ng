require 'fetchers/base_quota_summary_fetcher'

module VCAP::CloudController
  class SpaceQuotaSummaryFetcher < BaseQuotaSummaryFetcher
    private

    def memory_limit
      calculate_limit(@resource.space_quota_definition&.memory_limit, @resource.organization.quota_definition.memory_limit)
    end

    def memory_available
      [memory_limit, @resource.organization.memory_available].min - @resource.memory_used
    end

    def instance_memory_limit
      calculate_limit(@resource.space_quota_definition&.instance_memory_limit, @resource.organization.quota_definition.instance_memory_limit)
    end

    def app_instance_limit
      calculate_limit(@resource.space_quota_definition&.app_instance_limit, @resource.organization.quota_definition.app_instance_limit)
    end

    def app_tasks_limit
      calculate_limit(@resource.space_quota_definition&.app_task_limit, @resource.organization.quota_definition.app_task_limit)
    end

    # def paid_services_allowed
    #   calculate_boolean_limit(@resource.space_quota_definition&.non_basic_services_allowed, @resource.organization.quota_definition.non_basic_services_allowed)
    # end

    def service_instances_limit
      calculate_limit(@resource.space_quota_definition&.total_services, @resource.organization.quota_definition.total_services)
    end

    def service_keys_limit
      calculate_limit(@resource.space_quota_definition&.total_service_keys, @resource.organization.quota_definition.total_service_keys)
    end

    def routes_limit
      calculate_limit(@resource.space_quota_definition&.total_routes, @resource.organization.quota_definition.total_routes)
    end

    def total_reserved_ports_used
      VCAP::CloudController::SpaceReservedRoutePorts.new(@resource).count
    end

    def reserved_route_ports_limit
      calculate_limit(@resource.space_quota_definition&.total_reserved_route_ports, @resource.organization.quota_definition.total_reserved_route_ports)
    end

    def calculate_limit(space_limit, org_limit)
      if space_limit.nil? || space_limit == -1
        org_limit
      else
        [space_limit, org_limit].min
      end
    end

    def calculate_boolean_limit(space_limit, org_limit)
      !space_limit.nil? && space_limit && org_limit
    end
  end
end
