require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class BuildpackListFetcher
    def fetch_all(message)
      dataset = Buildpack.dataset
      filter(message, dataset)
    end

    def filter(message, dataset)
      if message.requested?(:names)
        dataset = dataset.where(name: message.names)
      end

      if message.requested?(:stacks)
        dataset = dataset.where(stack: message.stacks)
      end
      dataset
    end
  end
end
