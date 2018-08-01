module VCAP::CloudController
  class AddRouteFetcher
    def fetch(message)
      app = AppModel.where(guid: message.app_guid).eager(:space, space: :organization).all.first
      return nil if app.nil?

      process = app.processes_dataset.where(type: message.process_type).first
      route   = Route.where(guid: message.route_guid).first

      org = app.space ? app.space.organization : nil
      [app, route, process, app.space, org]
    end

    private

    def routes_dataset(space_guid)
      Route.dataset.select_all(Route.table_name).
        join(Space.table_name, id: :space_id).
        where(:"#{Space.table_name}__guid" => space_guid)
    end
  end
end
