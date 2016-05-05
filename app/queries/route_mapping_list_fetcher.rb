module VCAP::CloudController
  class RouteMappingListFetcher
    def fetch_all(message:)
      filter(RouteMappingModel.dataset, message)
    end

    def fetch_for_spaces(message:, space_guids:)
      dataset = RouteMappingModel.select_all(RouteMappingModel.table_name.to_sym).
                join(AppModel.table_name.to_sym, guid: :app_guid).
                where("#{AppModel.table_name}__space_guid".to_sym => space_guids)

      filter(dataset, message)
    end

    def fetch_for_app(message:, app_guid:)
      app = AppModel.where(guid: app_guid).eager(:space, :organization).all.first
      return nil unless app

      dataset = RouteMappingModel.where(app_guid: app_guid)

      [app, filter(dataset, message)]
    end

    private

    def filter(dataset, message)
      if message.requested?(:app_guids)
        dataset = dataset.where(app_guid: message.app_guids)
      end

      if message.requested?(:route_guids)
        dataset = dataset.where(route_guid: message.route_guids)
      end

      dataset
    end
  end
end
