module CloudController
  module Presenters
    module V2
      class RouteMappingPresenter < BasePresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::RouteMappingModel'

        def entity_hash(controller, route_mapping, opts, depth, parents, orphans=nil)
          entity = {
            'app_port' => present_app_port(route_mapping),
            'app_guid' => route_mapping.app_guid,
            'route_guid' => route_mapping.route_guid
          }
          entity.merge!(RelationsPresenter.new.to_hash(controller, route_mapping, opts, depth, parents, orphans))
        end

        private

        def present_app_port(route_mapping)
          return route_mapping.app_port if route_mapping.has_app_port_specified?

          nil
        end
      end
    end
  end
end
