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

        def purge_and_reseed_service_instances!
          ServiceUsageEvent.dataset.truncate

          column_map = {
            # using service_instance guid because we need a unique guid for the service_usage_event.  the database will not generate these for us.
            # because we are doing this insert as one query, we don't know how many guids to generate, so it is easiest to just re-use the guid that
            # is assigned to the matching service_instance.
            guid: :service_instances__guid,
            state: CREATED_EVENT_STATE,
            space_guid: :spaces__guid,
            space_name: :spaces__name,
            org_guid: :organizations__guid,
            service_instance_guid: :service_instances__guid,
            service_instance_name: :service_instances__name,
            # set service_instance_type to 'managed_service_instance' if is_gateway_service is true, otherwise set it to 'user_provided_service_instance'
            service_instance_type: Sequel.case({ { is_gateway_service: true } => 'managed_service_instance' }, 'user_provided_service_instance'),
            service_plan_guid: :service_plans__guid,
            service_plan_name: :service_plans__name,
            service_guid: :services__guid,
            service_label: :services__label,
            created_at: Sequel.datetime_class.now,
          }

          # use left_outer_joins for service_plans and services because user provided services do not have those relations, this allows them to be null
          usage_query = ServiceInstance.
            join(:spaces, id: :service_instances__space_id).
            join(:organizations, id: :spaces__organization_id).
            left_outer_join(:service_plans, id: :service_instances__service_plan_id).
            left_outer_join(:services, id: :service_plans__service_id).
            select(*column_map.values).
            order(:service_instances__id)

          ServiceUsageEvent.insert(column_map.keys, usage_query)
        end
      end
    end
  end
end
