module VCAP::CloudController
  class QuotaUsagePopulator
    def transform(quota, opts={})
      org_id = opts[:organization_id]

      unless org_id.nil?
        spaces = Space.where(organization: quota.organizations_dataset.filter(id: org_id))
        quota.org_usage = map_organization_usage(spaces) unless spaces.nil?
      end
    end

    private

    def map_organization_usage(spaces)
      quota = {}
      quota['routes'] = organization_routes_count(spaces)
      quota['services'] = organization_services_count(spaces)
      quota['memory'] = organization_memory_usage(spaces)
      quota
    end

    def organization_routes_count(spaces)
      route_count = 0
      spaces.eager(:routes).all do |space|
        route_count += space.routes.count
      end
      route_count
    end

    def organization_services_count(spaces)
      service_count = 0
      spaces.eager(:service_instances).all do |space|
        service_count += space.service_instances.count
      end
      service_count
    end

    def organization_memory_usage(spaces)
      memory_usage = 0
      spaces.eager(:apps).all do |space|
        space.apps.each do |app|
          memory_usage += app.memory * app.instances if app.started?
        end
      end
      memory_usage
    end
  end
end
