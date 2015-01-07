module VCAP::CloudController
  class PaginatedResult
    attr_reader :records, :total, :page, :per_page

    def initialize(records, total, page, per_page)
      @records  = records
      @total    = total
      @page     = page
      @per_page = per_page
    end
  end
end
