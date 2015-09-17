require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class AppListFetcher
    def fetch_all(pagination_options, message)
      dataset = AppModel.dataset
      filter(pagination_options, message, dataset)
    end

    def fetch(pagination_options, message, space_guids)
      dataset = AppModel.where(space_guid: space_guids)
      filter(pagination_options, message, dataset)
    end

    private

    def filter(pagination_options, message, dataset)
      if message.requested?(:names)
        dataset = dataset.where(name: message.names)
      end
      if message.requested?(:space_guids)
        dataset = dataset.where(space_guid: message.space_guids)
      end
      if message.requested?(:organization_guids)
        dataset = dataset.where(space_guid: Organization.where(guid: message.organization_guids).map(&:spaces).flatten.map(&:guid))
      end
      if message.requested?(:guids)
        dataset = dataset.where(guid: message.guids)
      end

      dataset.eager(:processes)

      SequelPaginator.new.get_page(dataset, pagination_options)
    end
  end
end
