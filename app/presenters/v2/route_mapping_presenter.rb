module CloudController
  module Presenters
    module V2
      class RouteMappingPresenter < BasePresenter
        extend PresenterProvider

        present_for_class 'VCAP::CloudController::RouteMapping'

        def entity_hash(controller, route_mapping, opts, depth, parents, orphans=nil)
          entity = {
            'app_port'   => route_mapping.app_port,
            'app_guid'   => route_mapping.app.guid,
            'route_guid' => route_mapping.route.guid,
          }

          entity.merge!(RelationsPresenter.new.to_hash(controller, route_mapping, opts, depth, parents, orphans))

          entity
        end
      end
    end
  end
end
