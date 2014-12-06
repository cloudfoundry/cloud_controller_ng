module VCAP::CloudController
  class AppPresenter
    def present_json(app)
      app_hash = {
        guid: app.guid,
        name: app.name,

        _links: {
          self:      { href: "/v3/apps/#{app.guid}" },
          processes: { href: "/v3/apps/#{app.guid}/processes" },
          space:     { href: "/v2/spaces/#{app.space_guid}" },
        }
      }

      MultiJson.dump(app_hash, pretty: true)
    end
  end
end
