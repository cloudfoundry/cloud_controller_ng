module VCAP::CloudController
  class DropletListFetcher
    def fetch_all(pagination_options, message)
      dataset = DropletModel.dataset
      filter(pagination_options, message, dataset)
    end

    def fetch(pagination_options, space_guids, message)
      dataset = DropletModel.select_all(:v3_droplets).join(:apps_v3, guid: :app_guid, space_guid: space_guids)
      filter(pagination_options, message, dataset)
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
