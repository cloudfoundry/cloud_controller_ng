require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class ServicePlanPresenter < BasePresenter
        def to_hash
          {
            guid: service_plan.guid,
            created_at: service_plan.created_at,
            updated_at: service_plan.updated_at,
            public: service_plan.public,
            available: service_plan.active?,
            name: service_plan.name,
            free: service_plan.free,
            description: service_plan.description,
            broker_catalog: {
              id: service_plan.unique_id,
              metadata: metadata,
              features: {
                bindable: service_plan.bindable?,
                plan_updateable: service_plan.plan_updateable?
              }
            },
            schemas: {
              service_instance: {
                create: parse_schema(service_plan.create_instance_schema),
                update: parse_schema(service_plan.update_instance_schema)
              },
              service_binding: {
                create: parse_schema(service_plan.create_binding_schema)
              }
            }
          }
        end

        private

        def metadata
          JSON.parse(service_plan.extra)
        rescue JSON::ParserError
          {}
        end

        def parse_schema(schema)
          { parameters: JSON.parse(schema) }
        rescue JSON::ParserError
          {}
        end

        def service_plan
          @resource
        end
      end
    end
  end
end
