require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class SpaceListFetcher
    def fetch(message:, guids:)
      dataset = Space.where(guid: guids)
      filter(message, dataset)
    end

    def fetch_all(message:)
      dataset = Space.dataset
      filter(message, dataset)
    end

    private

    def filter(message, dataset)
      if message.requested? :names
        dataset = dataset.where(name: message.names)
      end

      if message.requested? :organization_guids
        dataset = dataset.where(organization: Organization.where(guid: message.organization_guids))
      end

      dataset
    end
  end
end
