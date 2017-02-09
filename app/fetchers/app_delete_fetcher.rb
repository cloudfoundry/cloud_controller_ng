module VCAP::CloudController
  class AppDeleteFetcher
    def fetch(app_guid)
      app = AppModel.where(guid: app_guid).eager(:space, space: :organization).all.first
      return nil if app.nil?

      org = app.space ? app.space.organization : nil
      [app, app.space, org]
    end
  end
end
