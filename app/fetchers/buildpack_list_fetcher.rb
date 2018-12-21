require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'

module VCAP::CloudController
  class BuildpackListFetcher
    def fetch_all
      Buildpack.dataset
    end
  end
end
