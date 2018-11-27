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
      dataset
    end
  end
end
