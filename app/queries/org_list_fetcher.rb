require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class OrgListFetcher
    def fetch(message:, guids:)
      dataset = Organization.where(guid: guids)
      filter(message, dataset)
    end

    def fetch_all(message:)
      dataset = Organization.dataset
      filter(message, dataset)
    end

    private

    def filter(message, dataset)
      if message.requested?(:names)
        dataset = dataset.where(name: message.names)
      end

      dataset
    end
  end
end
