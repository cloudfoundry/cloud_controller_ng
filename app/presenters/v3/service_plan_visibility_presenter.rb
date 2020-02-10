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
          if service_plan.public?
            { type: 'public' }
          elsif service_plan.broker_space_scoped?
            {
              type: 'space',
              space: {
                name: service_plan.service_broker.space.name,
                guid: service_plan.service_broker.space.guid,
              }
            }
          elsif @visible_in_orgs.any?
            {
              type: 'organization',
              organizations: @visible_in_orgs.map { |org| { name: org.name, guid: org.guid } }
            }
          else
            { type: 'admin' }
          end
        end

        private

        def service_plan
          @resource
        end
      end
    end
  end
end

