require 'fetchers/base_quota_summary_fetcher'

module VCAP::CloudController
  class OrganizationQuotaSummaryFetcher < BaseQuotaSummaryFetcher
    private

    def memory_limit
      @resource.quota_definition.memory_limit
    end

    def memory_available
      @resource.memory_available
    end

    def instance_memory_limit
      @resource.quota_definition.instance_memory_limit
    end

    def app_instance_limit
      @resource.quota_definition.app_instance_limit
    end

    def app_tasks_limit
      @resource.quota_definition.app_task_limit
    end

    def paid_services_allowed
      @resource.quota_definition.non_basic_services_allowed
    end

    def service_instances_limit
      @resource.quota_definition.total_services
    end

    def service_keys_limit
      @resource.quota_definition.total_service_keys
    end
  end
end
