module VCAP::CloudController
  class LogAccessFetcher
    def app_exists?(guid)
      AppModel.where(guid: guid).count > 0 ||
        App.where(guid: guid).count > 0
    end

    def app_exists_by_space?(guid, space_guids)
      AppModel.where(guid: guid, space_guid: space_guids).count > 0 ||
        App.dataset.select(:processes__guid).
          where(processes__guid: guid).
          join(:apps, apps__guid: :app_guid).
          where(apps__space_guid: space_guids).count > 0
    end
  end
end
