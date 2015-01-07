module VCAP::CloudController
  class PaginationRequest
    attr_reader :page, :per_page

    def initialize(page, per_page)
      @page     = page
      @per_page = per_page
    end
  end
end
