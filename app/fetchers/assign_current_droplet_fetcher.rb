module VCAP::CloudController
  class AssignCurrentDropletFetcher
    def fetch(app_guid, droplet_guid)
      app = AppModel.where(guid: app_guid).first
      return nil if app.nil?

      droplet = app.droplets.detect { |d| d.guid == droplet_guid }
      [app, app.space, droplet]
    end
  end
end
