module VCAP::CloudController
  class LogAccessFetcher
    def app_exists?(guid)
      AppModel.where(guid: guid).any? ||
        ProcessModel.where(guid: guid).any?
    end

    def app_exists_by_space?(guid, space_guids)
      AppModel.where(guid: guid, space_guid: space_guids).any? ||
        ProcessModel.join(:apps, guid: :app_guid).
          where(processes__guid: guid, apps__space_guid: space_guids).any?
    end
  end
end
