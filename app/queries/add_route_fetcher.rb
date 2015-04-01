module VCAP::CloudController
  class AddRouteFetcher
    def fetch(app_guid, route_guid)
      app = apps_dataset.where(:"#{AppModel.table_name}__guid" => app_guid).first
      return [nil, nil] if app.nil?
      route = routes_dataset(app.space_guid).where(:"#{Route.table_name}__guid" => route_guid).first
      [app, route]
    end

    private

    def apps_dataset
      AppModel.dataset
    end

    def routes_dataset(space_guid)
      ds = Route.dataset
      ds.select_all(Route.table_name).
        join(Space.table_name, id: :space_id).
        where(:"#{Space.table_name}__guid" => space_guid)
    end
  end
end
