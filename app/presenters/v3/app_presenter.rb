module VCAP::CloudController
  class AppPresenter
    attr_reader :app

    def initialize(app)
      @app = app
    end

    def present_json
      processes = app.processes.map do |p|
        { href: "/v3/processes/#{p.guid}" }
      end
      app_hash = {
        guid:   app.guid,

        _links: {
          self:      { href: "/v3/apps/#{app.guid}" },
          processes: processes,
          space:     { href: "/v2/spaces/#{app.space_guid}" },
        }
      }

      MultiJson.dump(app_hash, pretty: true)
    end
  end
end
