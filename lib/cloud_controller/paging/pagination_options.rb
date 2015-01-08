module VCAP::CloudController
  class PaginationOptions
    attr_reader :page, :per_page

    def initialize(page, per_page)
      @page     = page
      @per_page = per_page
    end

    def self.from_params(params)
      page     = params['page'].to_i
      per_page = params['per_page'].to_i
      PaginationOptions.new(page, per_page)
    end
  end
end
