module VCAP::CloudController
  class AddRouteFetcher
    def fetch(app_guid, route_guid)
      app = AppModel.where(guid: app_guid).eager(:space, space: :organization).all.first
      return nil if app.nil?

      web_process = app.processes_dataset.where(type: 'web').first
      route       = routes_dataset(app.space_guid).where(:"#{Route.table_name}__guid" => route_guid).first

      org = app.space ? app.space.organization : nil
      [app, route, web_process, app.space, org]
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
