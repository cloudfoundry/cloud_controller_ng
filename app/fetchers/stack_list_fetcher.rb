require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class StackListFetcher
    def fetch_all
      Stack.dataset
    end
  end
end
