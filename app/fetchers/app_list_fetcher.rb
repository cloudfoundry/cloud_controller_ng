require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/label_selector_parser'

module VCAP::CloudController
  class AppListFetcher
    def fetch_all(message)
      dataset = AppModel.dataset
      filter(message, dataset)
    end

    def fetch(message, space_guids)
      dataset = AppModel.where(space_guid: space_guids)
      filter(message, dataset)
    end

    private

    def filter(message, dataset)
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
      if message.requested?(:label_selector)
        dataset = LabelSelectorParser.add_selector_queries(AppLabelModel, dataset, message.label_selector)
      end

      dataset.eager(:processes)
    end
  end
end
