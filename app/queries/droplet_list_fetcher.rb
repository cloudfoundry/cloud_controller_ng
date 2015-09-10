module VCAP::CloudController
  class DropletListFetcher
    def fetch_all(pagination_options, facets)
      dataset = DropletModel.dataset
      filter(pagination_options, facets, dataset)
    end

    def fetch(pagination_options, space_guids, facets={})
      dataset = DropletModel.select_all(:v3_droplets).join(:apps_v3, guid: :app_guid, space_guid: space_guids)
      filter(pagination_options, facets, dataset)
    end

    private

    def filter(pagination_options, facets, dataset)
      if facets['app_guids']
        dataset = dataset.where(app_guid: facets['app_guids'])
      end

      if facets['states']
        dataset = dataset.where(state: facets['states'])
      end

      SequelPaginator.new.get_page(dataset, pagination_options)
    end
  end
end
