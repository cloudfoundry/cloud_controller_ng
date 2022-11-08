module VCAP::CloudController
  class LogAccessFetcher
    def app_exists?(guid)
      !AppModel.where(guid: guid).empty? ||
        !ProcessModel.where(guid: guid).empty?
    end

    def app_exists_by_space?(guid, space_guids)
      !AppModel.where(guid: guid, space_guid: space_guids).empty? ||
        !ProcessModel.join(:apps, guid: :app_guid).
          where(processes__guid: guid, apps__space_guid: space_guids).empty?
    end
  end
end
