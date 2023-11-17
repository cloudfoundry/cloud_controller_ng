module VCAP::CloudController
  class OrganizationQuotaUsage
    def initialize(organization)
      @organization = organization
    end

    def routes
      OrganizationRoutes.new(@organization).count
    end

    def service_instances
      @organization.managed_service_instances_dataset.count
    end

    def private_domains
      @organization.owned_private_domains_dataset.count
    end

    def service_keys
      VCAP::CloudController::ServiceKey.dataset.join(:service_instances, id: :service_instance_id).
        join(:spaces, id: :space_id).
        where(spaces__organization_id: @organization.id).
        count || 0
    end

    def reserved_route_ports
      OrganizationReservedRoutePorts.new(@organization).count
    end

    def app_tasks
      @organization.running_and_pending_tasks_count
    end
  end
end
