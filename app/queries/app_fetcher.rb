module VCAP::CloudController
  class AppFetcher
    def fetch(app_guid)
      AppModel.where(guid: app_guid).eager(:processes).first
    end
  end
end
