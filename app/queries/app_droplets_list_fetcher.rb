module VCAP::CloudController
  class AppDropletsListFetcher
    def fetch(app_guid, pagination_options, message)
      dataset = DropletModel.select_all(:v3_droplets).where(app_guid: app_guid)
      filter(pagination_options, message, dataset)
    end

    private

    def filter(pagination_options, message, dataset)
      if message.requested?(:states)
        dataset = dataset.where(state: message.states)
      end

      SequelPaginator.new.get_page(dataset, pagination_options)
    end
  end
end
