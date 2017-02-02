require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class OrgListFetcher
    def fetch(guids)
      Organization.where(guid: guids)
    end

    def fetch_all
      Organization.dataset
    end
  end
end
