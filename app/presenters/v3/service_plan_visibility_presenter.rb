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
              guid: service_plan.service_broker.space.guid,
              name: service_plan.service_broker.space.name,
            }
          end

          if visibility[:type] == VCAP::CloudController::ServicePlanVisibilityTypes::ORGANIZATION && !@visible_in_orgs.nil?
            visibility[:organizations] = @visible_in_orgs.map { |org| { guid: org.guid, name: org.name } }
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
