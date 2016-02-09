module VCAP::CloudController
  class RouteMappingListFetcher
    def fetch(pagination_options, app_guid)
      dataset = RouteMappingModel.where(app_guid: app_guid)
      SequelPaginator.new.get_page(dataset, pagination_options)
    end
  end
end
