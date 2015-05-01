module VCAP::CloudController
  class DropletListFetcher
    def fetch_all(pagination_options)
      dataset = DropletModel.dataset
      paginate(dataset, pagination_options)
    end

    def fetch(pagination_options, space_guids)
      dataset = DropletModel.select_all(:v3_droplets).join(:apps_v3, guid: :app_guid, space_guid: space_guids)
      paginate(dataset, pagination_options)
    end

    private

    def paginate(dataset, pagination_options)
      SequelPaginator.new.get_page(dataset, pagination_options)
    end
  end
end
