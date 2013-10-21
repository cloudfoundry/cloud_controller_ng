# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::RestController

  # Paginates a dataset
  class Paginator
    # Paginate and render a dataset to json.
    #
    # @param [RestController] controller Controller for the
    # dataset being paginated.
    #
    # @param [Sequel::Dataset] ds Dataset to paginate.
    #
    # @param [String] path Path used to fetch the dataset.
    #
    # @option opts [Integer] :page Page number to start at.  Defaults to 1.
    #
    # @option opts [Integer] :results_per_page Number of results to include
    # per page.  Defaults to 50.
    #
    # @option opts [Boolean] :pretty Controlls pretty formating of the encoded
    # json.  Defaults to true.
    #
    # @option opts [Integer] :inline_relations_depth Depth to recursively
    # exapend relationships in addition to providing the URLs.
    #
    # @option opts [Integer] :max_inline Maximum number of objects to
    # expand inline in a relationship.
    #
    # @return [String] Json encoding pagination of the dataset.
    def self.render_json(controller, ds, path, opts)
      self.new(controller, ds, path, opts).render_json
    end

    # Create a paginator.
    #
    # @param [RestController] controller Controller for the
    # dataset being paginated.
    #
    # @param [Sequel::Dataset] ds Dataset to paginate.
    #
    # @param [String] path Path used to fetch the dataset.
    #
    # @option opts [Integer] :page Page number to start at.  Defaults to 1.
    #
    # @option opts [Integer] :results_per_page Number of results to include
    # per page.  Defaults to 50.
    #
    # @option opts [Boolean] :pretty Controlls pretty formating of the encoded
    # json.  Defaults to true.
    #
    # @option opts [Integer] :inline_relations_depth Depth to recursively
    # exapend relationships in addition to providing the URLs.
    #
    # @option opts [Integer] :max_inline Maximum number of objects to
    # expand inline in a relationship.
    def initialize(controller, ds, path, opts)
      page       = opts[:page] || 1
      page_size  = opts[:results_per_page] || 50
      criteria = opts[:order_by] || :id

      @paginated = ds.order_by(criteria).extension(:pagination).paginate(page, page_size)
      @serialization = opts[:serialization] || ObjectSerialization

      @controller = controller
      @path = path
      @opts = opts
    end

    # Pagination
    #
    # @return [String] Json encoding pagination of the dataset.
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

    private

    def resources
      @paginated.all.map do |m|
        @serialization.to_hash(@controller, m, @opts)
      end
    end

    def prev_page_url
      @paginated.prev_page ? url(@paginated.prev_page) : nil
    end

    def next_page_url
      @paginated.next_page ? url(@paginated.next_page) : nil
    end

    def url(page)
      res = "#{@path}?"
      if @opts[:inline_relations_depth]
        res += "inline-relations-depth=#{@opts[:inline_relations_depth]}&"
      end
      res += "q=#{URI.encode(@opts[:q])}&" if @opts[:q]
      res += "page=#{page}&results-per-page=#{@paginated.page_size}"
    end
  end
end
