module VCAP::CloudController
  class IncludeAppRouteDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w(route).include?(i) }
      end

      def decorate(hash, apps)
        hash[:included] ||= {}
        route_guids = apps.map(&:route_guids).flatten.uniq

        routes = Route.where(guid: route_guids).order(:created_at).
          eager(Presenters::V3::RoutePresenter.associated_resources).all

        hash[:included][:routes] = routes.map { |route| Presenters::V3::RoutePresenter.new(route).to_hash }
        hash
      end
    end
  end
end
