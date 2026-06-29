module VCAP::CloudController
  class IncludeRoutePolicyRouteDecorator
    # Handles `?include=route` for GET /v3/route_policies
    # Includes the route resources associated with the route policies

    def self.match?(include_params)
      include_params&.include?('route')
    end

    def self.decorate(hash, route_policies)
      hash[:included] ||= {}

      # Collect all unique route IDs from route policies
      route_ids = route_policies.map(&:route_id).uniq

      # Fetch routes with their associations
      routes = Route.where(id: route_ids).
               order(:created_at, :guid).
               eager(Presenters::V3::RoutePresenter.associated_resources).all

      # Present routes
      hash[:included][:routes] = routes.map { |route| Presenters::V3::RoutePresenter.new(route).to_hash }

      hash
    end
  end
end
