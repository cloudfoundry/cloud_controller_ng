module VCAP::CloudController
  class TaskCreateFetcher
    def fetch(app_guid:, droplet_guid: nil)
      app = AppModel.where(guid: app_guid).first

      droplet = app.droplets_dataset.where(guid: droplet_guid).first if droplet_guid

      return nil if app.nil?

      [app, app.space, droplet]
    end
  end
end
