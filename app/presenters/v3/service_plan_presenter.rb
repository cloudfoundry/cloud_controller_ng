require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class ServicePlanPresenter < BasePresenter
        def to_hash
          {
            guid: service_plan.guid,
          }
        end

        private

        def service_plan
          @resource
        end
      end
    end
  end
end
