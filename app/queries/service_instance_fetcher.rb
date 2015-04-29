module VCAP::CloudController
  class ServiceInstanceFetcher
    def fetch(guid)
      instance = ServiceInstance.first(guid: guid)

      if instance.managed_instance?
        plan = instance.service_plan
        service = plan.service
      end

      [instance, {
          space: instance.space,
          plan: plan,
          service: service
      }]
    end
  end
end
