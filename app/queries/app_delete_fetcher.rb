module VCAP::CloudController
  class AppDeleteFetcher
    def fetch(app_guid)
      AppModel.where(guid: app_guid)
    end
  end
end
