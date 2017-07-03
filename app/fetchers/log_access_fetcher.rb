module VCAP::CloudController
  class LogAccessFetcher
    def app_exists?(guid)
      AppModel.where(guid: guid).count > 0 ||
        ProcessModel.where(guid: guid).count > 0
    end

    def app_exists_by_space?(guid, space_guids)
      AppModel.where(guid: guid, space_guid: space_guids).count > 0 ||
        ProcessModel.dataset.select("#{ProcessModel.table_name}__guid".to_sym).
          where("#{ProcessModel.table_name}__guid".to_sym => guid).
          join(AppModel.table_name, "#{AppModel.table_name}__guid".to_sym => :app_guid).
          where("#{AppModel.table_name}__space_guid".to_sym => space_guids).count > 0
    end
  end
end
