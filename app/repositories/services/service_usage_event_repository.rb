module VCAP::CloudController
  module Repositories
    module Services
      class ServiceUsageEventRepository

        def find(guid)
          ServiceUsageEvent.find(guid: guid)
        end

        def create_from_service_instance(service_instance, state_name)
          service_plan = service_instance.service_plan
          service = service_plan.service
          space = service_instance.space

          ServiceUsageEvent.create(state: state_name,
                                   org_guid: space.organization_guid,
                                   space_guid: space.guid,
                                   space_name: space.name,
                                   service_instance_guid: service_instance.guid,
                                   service_instance_name: service_instance.name,
                                   service_plan_guid: service_plan.guid,
                                   service_plan_name: service_plan.name,
                                   service_guid: service.guid,
                                   service_label: service.label
          )
        end

      end
    end
  end
end
