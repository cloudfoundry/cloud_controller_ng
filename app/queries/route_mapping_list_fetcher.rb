module VCAP::CloudController
  class RouteMappingListFetcher
    def fetch_all
      RouteMappingModel.dataset
    end

    def fetch_for_spaces(space_guids:)
      RouteMappingModel.select_all(RouteMappingModel.table_name.to_sym).
        join(AppModel.table_name.to_sym, guid: :app_guid).
        where("#{AppModel.table_name}__space_guid".to_sym => space_guids)
    end

    def fetch_for_app(app_guid:)
      app = AppModel.where(guid: app_guid).eager(:space, :organization).all.first
      return nil unless app
      [app, RouteMappingModel.where(app_guid: app_guid)]
    end
  end
end
