module CloudController
  module Presenters
    module V2
      class ServicePlanPresenter < BasePresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::ServicePlan'

        def entity_hash(controller, plan, opts, depth, parents, orphans=nil)
          schemas = {
            'schemas' => {
              'service_instance' => {
                'create' => {
                  'parameters' => {}
                }
              }
            }
          }

          entity = DefaultPresenter.new.entity_hash(controller, plan, opts, depth, parents, orphans)
          entity.merge!(schemas)
          entity.delete('create_instance_schema')
          entity
        end
      end
    end
  end
end
