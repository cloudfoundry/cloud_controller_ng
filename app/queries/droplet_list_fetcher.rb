module VCAP::CloudController
  class DropletListFetcher
    def fetch_all(message:)
      dataset = DropletModel.dataset
      filter(message, dataset)
    end

    def fetch_for_spaces(space_guids:, message:)
      dataset = DropletModel.select_all(:v3_droplets).join(:apps_v3, guid: :app_guid, space_guid: space_guids)
      filter(message, dataset)
    end

    def fetch_for_app(message:)
      app = AppModel.where(guid: message.app_guid).eager(:space, space: :organization).all.first
      return nil unless app
      [app, filter(message, app.droplets_dataset)]
    end

    private

    def filter(message, dataset)
      if message.requested?(:app_guids)
        dataset = dataset.where(app_guid: message.app_guids)
      end

      if message.requested?(:states)
        dataset = dataset.where(state: message.states)
      end

      dataset
    end
  end
end
