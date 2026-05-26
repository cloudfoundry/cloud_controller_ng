module VCAP::CloudController
  class IncludeRoutePoliciesDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w[route_policies].include?(i) }
      end

      def decorate(hash, routes)
        hash[:included] ||= {}
        route_ids = routes.map(&:id).uniq
        route_policies = RoutePolicy.where(route_id: route_ids).
                         eager(:route, :labels, :annotations).all

        hash[:included][:route_policies] = route_policies.map { |rp| Presenters::V3::RoutePolicyPresenter.new(rp).to_hash }
        hash
      end
    end
  end
end
