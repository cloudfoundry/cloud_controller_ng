module VCAP::CloudController
  class RouteMappingListFetcher
    def fetch_all(message:)
      pagination_options = message.pagination_options
      SequelPaginator.new.get_page(RouteMappingModel.dataset, pagination_options)
    end

    def fetch_for_spaces(message:, space_guids:)
      pagination_options = message.pagination_options
      dataset = RouteMappingModel.select_all(RouteMappingModel.table_name.to_sym).
                join(AppModel.table_name.to_sym, guid: :app_guid).
                where("#{AppModel.table_name}__space_guid".to_sym => space_guids)

      SequelPaginator.new.get_page(dataset, pagination_options)
    end

    def fetch_for_app(message:, app_guid:)
      pagination_options = message.pagination_options
      app = AppModel.where(guid: app_guid).eager(:space, :organization).all.first
      return nil unless app
      dataset = RouteMappingModel.where(app_guid: app_guid)
      [app, SequelPaginator.new.get_page(dataset, pagination_options)]
    end
  end
end
