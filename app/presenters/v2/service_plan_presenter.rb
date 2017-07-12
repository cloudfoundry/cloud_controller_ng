module CloudController
  module Presenters
    module V2
      class ServicePlanPresenter < BasePresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::ServicePlan'

        def entity_hash(controller, plan, opts, depth, parents, orphans=nil)
          entity = DefaultPresenter.new.entity_hash(controller, plan, opts, depth, parents, orphans)

          schemas = present_schemas(plan)
          entity.merge!(schemas)
          entity.delete('create_instance_schema')
          entity.delete('update_instance_schema')

          entity
        end

        private

        def present_schemas(plan)
          create_instance_schema = parse_schema(plan.create_instance_schema)
          update_instance_schema = parse_schema(plan.update_instance_schema)
          {
            'schemas' => {
              'service_instance' => {
                'create' => {
                  'parameters' => create_instance_schema
                },
                'update' => {
                    'parameters' => update_instance_schema

                }
              }
            }
          }
        end

        def parse_schema(schema)
          return {} unless schema

          begin
            JSON.parse(schema)
          rescue JSON::ParserError
            {}
          end
        end
      end
    end
  end
end
