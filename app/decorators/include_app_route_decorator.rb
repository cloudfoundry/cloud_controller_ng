module VCAP::CloudController
  class IncludeAppRouteDecorator
    class << self
      def match?(include)
        include&.any? { |i| %w(route).include?(i) }
      end

      def decorate(hash, apps)
        hash[:included] ||= {}

        app_guids = apps.map(&:guid)

        routes = Route.select_all(:routes).
                 inner_join(:route_mappings, route_guid: :guid).
                 where(route_mappings__app_guid: app_guids).
                 order(:routes__created_at).all

        hash[:included][:routes] = routes.map { |route| Presenters::V3::RoutePresenter.new(route).to_hash }
        hash
      end
    end
  end
end
