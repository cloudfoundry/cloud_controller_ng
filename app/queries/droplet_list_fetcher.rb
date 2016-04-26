module VCAP::CloudController
  class DropletListFetcher
    def fetch_all(message:)
      pagination_options = message.pagination_options
      dataset = DropletModel.dataset
      filter(pagination_options, message, dataset)
    end

    def fetch_for_spaces(space_guids:, message:)
      pagination_options = message.pagination_options
      dataset = DropletModel.select_all(:v3_droplets).join(:apps_v3, guid: :app_guid, space_guid: space_guids)
      filter(pagination_options, message, dataset)
    end

    def fetch_for_app(message:)
      pagination_options = message.pagination_options
      app = AppModel.where(guid: message.app_guid).eager(:space, space: :organization).all.first
      return nil unless app
      [app, filter(pagination_options, message, app.droplets_dataset)]
    end

    private

    def filter(pagination_options, message, dataset)
      if message.requested?(:app_guids)
        dataset = dataset.where(app_guid: message.app_guids)
      end

      if message.requested?(:states)
        dataset = dataset.where(state: message.states)
      end

      SequelPaginator.new.get_page(dataset, pagination_options)
    end
  end
end
