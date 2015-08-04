module VCAP::CloudController
  class AppDropletsListFetcher
    def fetch(app_guid, pagination_options, facets={})
      dataset = DropletModel.select_all(:v3_droplets).where(app_guid: app_guid)
      filter(pagination_options, facets, dataset)
    end

    private

    def filter(pagination_options, facets, dataset)
      if facets['states']
        dataset = dataset.where(state: facets['states'])
      end

      SequelPaginator.new.get_page(dataset, pagination_options)
    end
  end
end
