module VCAP::CloudController
  class LogAccessFetcher
    def app_exists?(guid)
      AppModel.where(guid: guid).count.positive? ||
        App.where(guid: guid).count.positive?
    end

    def app_exists_by_space?(guid, space_guids)
      AppModel.where(guid: guid, space_guid: space_guids).count.positive? ||
        App.dataset.select("#{App.table_name}__guid".to_sym).
          where("#{App.table_name}__guid".to_sym => guid).
          join(AppModel.table_name, "#{AppModel.table_name}__guid".to_sym => :app_guid).
          where("#{AppModel.table_name}__space_guid".to_sym => space_guids).count.positive?
    end
  end
end
