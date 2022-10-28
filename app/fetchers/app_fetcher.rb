module VCAP::CloudController
  class AppFetcher
    def fetch(app_guid)
      app = AppModel.where(guid: app_guid).first
      return nil if app.nil?

      [app, app.space]
    end
  end
end
