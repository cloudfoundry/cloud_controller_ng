require 'presenters/v3/route_presenter'

module VCAP
  module CloudController
    module IncludeBindingRouteDecorator
      class << self
        def decorate(hash, route_bindings)
          extra = {
            included: { routes: routes(route_bindings) }
          }

          hash.deep_merge(extra)
        end

        def match?(include_params)
          include_params&.include?('route')
        end

        private

        def routes(route_bindings)
          route_ids = route_bindings.map(&:route_id)
          routes = Route.where(id: route_ids).order_by(:created_at).
                   eager(Presenters::V3::RoutePresenter.associated_resources).all
          routes.map { |route| Presenters::V3::RoutePresenter.new(route).to_hash }
        end
      end
    end
  end
end
