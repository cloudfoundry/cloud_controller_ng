module VCAP::CloudController
  class AppFetcher
    def fetch(app_guid)
      AppModel.where(guid: app_guid).eager(:processes).all.first
    end
  end
end
