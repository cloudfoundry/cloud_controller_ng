module VCAP::CloudController
  class TaskCreateFetcher
    def fetch(app_guid:, droplet_guid: nil)
      app = AppModel.where(guid: app_guid).eager(
        :processes,
        :space,
        :droplet,
        space: :organization
      ).all.first

      if droplet_guid
        droplet = app.droplets_dataset.where(guid: droplet_guid).first
      end

      return nil if app.nil?
      [app, app.space, app.space.organization, droplet]
    end
  end
end
