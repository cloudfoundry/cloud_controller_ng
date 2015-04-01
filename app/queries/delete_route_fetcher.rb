module VCAP::CloudController
  class DeleteRouteFetcher
    def fetch(app_guid, route_guid)
      app = AppModel.find(guid: app_guid)
      return [nil, nil] if app.nil?
      route = app.routes_dataset.where(guid: route_guid).first
      [app, route]
    end
  end
end
