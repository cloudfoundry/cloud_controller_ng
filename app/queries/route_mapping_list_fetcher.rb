module VCAP::CloudController
  class RouteMappingListFetcher
    def initialize(message:)
      @message = message
    end

    def fetch_all
      filter(RouteMappingModel.dataset)
    end

    def fetch_for_spaces(space_guids:)
      filter(
        RouteMappingModel.select_all(RouteMappingModel.table_name.to_sym).
          join(AppModel.table_name.to_sym, guid: :app_guid).
          where("#{AppModel.table_name}__space_guid".to_sym => space_guids)
      )
    end

    def fetch_for_app(app_guid:)
      app = AppModel.where(guid: app_guid).eager(:space, :organization).all.first
      return nil unless app

      [app, filter(RouteMappingModel.where(app_guid: app_guid))]
    end

    private

    def filter(dataset)
      if @message.requested?(:app_guids)
        dataset = dataset.where(app_guid: @message.app_guids)
      end

      if @message.requested?(:route_guids)
        dataset = dataset.where(route_guid: @message.route_guids)
      end

      dataset
    end
  end
end
