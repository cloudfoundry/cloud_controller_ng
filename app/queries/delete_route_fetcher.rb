module VCAP::CloudController
  class DeleteRouteFetcher
    def fetch(app_guid, route_guid)
      app = AppModel.
        where(guid: app_guid).
        eager(
          :space,
          space: :organization,
          routes: proc { |ds| ds.where(guid: route_guid) }).all.first

      return nil if app.nil?

      org = app.space ? app.space.organization : nil
      [app, app.routes.first, app.space, org]
    end
  end
end
