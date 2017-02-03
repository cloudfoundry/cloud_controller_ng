require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class SpaceListFetcher
    def fetch(guids:)
      Space.where(guid: guids)
    end

    def fetch_all
      Space.dataset
    end
  end
end
