module VCAP::CloudController
  class AppRevisionsFetcher
    def self.fetch(app_guid, message)
      if message.requested?(:versions)
        RevisionModel.where(app: app_guid, version: message.versions)
      else
        RevisionModel.where(app: app_guid)
      end
    end
  end
end
