require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class ServicePlanVisibilityPresenter < BasePresenter
        def initialize(service_plan, visible_in_orgs)
          super(service_plan)
          @visible_in_orgs = visible_in_orgs
        end

        def to_hash
          visibility = { type: service_plan.visibility_type }

          if visibility[:type] == VCAP::CloudController::ServicePlanVisibilityTypes::SPACE
            visibility[:space] = {
              name: service_plan.service_broker.space.name,
              guid: service_plan.service_broker.space.guid,
            }
          end

          if visibility[:type] == VCAP::CloudController::ServicePlanVisibilityTypes::ORGANIZATION
            visibility[:organizations] = @visible_in_orgs.map { |org| { name: org.name, guid: org.guid } }
          end

          return visibility
        end

        private

        def service_plan
          @resource
        end
      end
    end
  end
end
