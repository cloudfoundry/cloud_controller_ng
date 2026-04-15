module VCAP::CloudController
  class IncludeAccessRuleRouteDecorator
    # Handles `?include=route` for GET /v3/access_rules
    # Includes the route resources associated with the access rules

    def self.match?(include_params)
      include_params&.include?('route')
    end

    def self.decorate(hash, access_rules)
      hash[:included] ||= {}

      # Collect all unique route IDs from access rules
      route_ids = access_rules.map(&:route_id).uniq

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
