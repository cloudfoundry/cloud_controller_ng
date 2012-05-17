# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController
  class Paginator
    def self.render_json(controller, ds, opts)
      self.new(controller, ds, opts).render_json
    end

    def initialize(controller, ds, opts)
      page       = opts[:page] || 1
      page_size  = opts[:results_per_page] || 50
      @paginated = ds.paginate(page, page_size)

      @controller = controller
      @opts = opts
    end

    def render_json
      res = {
        :total_results => @paginated.pagination_record_count,
        :total_pages   => @paginated.page_count,
        :prev_url      => prev_page_url,
        :next_url      => next_page_url,
        :resources     => resources,
      }

      Yajl::Encoder.encode(res, :pretty => true)
    end

    def resources
      @paginated.all.map do |m|
        ObjectSerialization.to_hash(@controller, m, @opts)
      end
    end

    def prev_page_url
      @paginated.prev_page ? url(@paginated.prev_page) : nil
    end

    def next_page_url
      @paginated.next_page ? url(@paginated.next_page) : nil
    end

    def url(page)
      res = "#{@controller.path}?"
      res += "q=#{@opts[:q]}&" if @opts[:q]
      res += "page=#{page}&results-per-page=#{@paginated.page_size}"
    end
  end
end
