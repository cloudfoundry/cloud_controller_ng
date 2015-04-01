module VCAP::CloudController
  class AddRouteFetcher
    def fetch(app_guid, route_guid)
      app = AppModel.find(guid: app_guid)
      return [nil, nil] if app.nil?
      route = routes_dataset(app.space_guid).where(:"#{Route.table_name}__guid" => route_guid).first
      [app, route]
    end

    private

    def routes_dataset(space_guid)
      ds = Route.dataset
      ds.select_all(Route.table_name).
        join(Space.table_name, id: :space_id).
        where(:"#{Space.table_name}__guid" => space_guid)
    end
  end
end
