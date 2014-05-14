module VCAP::CloudController
  module Repositories
    module Services
      class ServiceUsageEventRepository

        DELETED_EVENT_STATE = 'DELETED'.freeze
        CREATED_EVENT_STATE = 'CREATED'.freeze

        def find(guid)
          ServiceUsageEvent.find(guid: guid)
        end

        def create_from_service_instance(service_instance, state_name)
          space = service_instance.space
          values = {
            state: state_name,
            org_guid: space.organization_guid,
            space_guid: space.guid,
            space_name: space.name,
            service_instance_guid: service_instance.guid,
            service_instance_name: service_instance.name,
            service_instance_type: service_instance.type,
          }

          if 'managed_service_instance' == service_instance.type
            service_plan = service_instance.service_plan
            service = service_plan.service
            values = values.merge({
                                    service_plan_guid: service_plan.guid,
                                    service_plan_name: service_plan.name,
                                    service_guid: service.guid,
                                    service_label: service.label
                                  })
          end

          ServiceUsageEvent.create(values)
        end

        def created_event_from_service_instance(service_instance)
          create_from_service_instance(service_instance, CREATED_EVENT_STATE)
        end

        def deleted_event_from_service_instance(service_instance)
          create_from_service_instance(service_instance, DELETED_EVENT_STATE)
        end

      end
    end
  end
end
