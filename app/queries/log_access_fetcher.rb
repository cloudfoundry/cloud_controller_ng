module VCAP::CloudController
  class LogAccessFetcher
    def app_exists?(guid)
      AppModel.where(guid: guid).count > 0 ||
        App.where(guid: guid).count > 0
    end

    def app_exists_by_space?(guid, space_guids)
      AppModel.where(guid: guid, space_guid: space_guids).count > 0 ||
        App.dataset.select(:apps).
          where(apps__guid: guid).
          join(:spaces, id: :space_id).
          where(spaces__guid: space_guids).count > 0
    end
  end
end
