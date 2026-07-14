module VCAP::CloudController
  class IncludeRoutePoliciesDecorator
    class << self
      def match?(include)
        include&.include?('route_policies')
      end

      def decorate(hash, routes)
        hash[:included] ||= {}
        route_ids = routes.map(&:id).uniq
        route_policies = RoutePolicy.where(route_id: route_ids).
                         order(:created_at, :guid).
                         eager(Presenters::V3::RoutePolicyPresenter.associated_resources).all

        hash[:included][:route_policies] = route_policies.map { |rp| Presenters::V3::RoutePolicyPresenter.new(rp).to_hash }
        hash
      end
    end
  end
end
