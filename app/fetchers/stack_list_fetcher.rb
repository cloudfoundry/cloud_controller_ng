require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class StackListFetcher
    def fetch_all(message)
      dataset = Stack.dataset
      filter(message, dataset)
    end

    def filter(message, dataset)
      if message.requested?(:names)
        dataset = dataset.where(name: message.names)
      end

      if message.requested?(:label_selector)
        dataset = LabelSelectorQueryGenerator.add_selector_queries(
          label_klass: StackLabelModel,
          resource_dataset: dataset,
          requirements: message.requirements,
          resource_klass: Stack,
        )
      end
      dataset
    end
  end
end
