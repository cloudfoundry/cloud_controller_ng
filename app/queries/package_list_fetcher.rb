module VCAP::CloudController
  class PackageListFetcher
    def fetch_all(pagination_options)
      dataset = PackageModel.dataset
      paginate(dataset, pagination_options)
    end

    def fetch(pagination_options, space_guids)
      dataset = PackageModel.select_all(:packages).join(:apps_v3, guid: :app_guid, space_guid: space_guids)
      paginate(dataset, pagination_options)
    end

    private

    def paginate(dataset, pagination_options)
      SequelPaginator.new.get_page(dataset, pagination_options)
    end
  end
end
