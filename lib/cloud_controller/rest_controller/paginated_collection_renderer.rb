require 'addressable/uri'

module VCAP::CloudController::RestController
  class PaginatedCollectionRenderer
    def initialize(eager_loader, serializer)
      @eager_loader = eager_loader
      @serializer = serializer
    end

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
    def render_json(controller, ds, path, opts, request_params)
      page      = opts[:page] || 1
      page_size = opts[:results_per_page] || 50
      criteria  = opts[:order_by] || :id

      paginated = ds.order_by(criteria).extension(:pagination).paginate(page, page_size)

      dataset = @eager_loader.eager_load_dataset(
        paginated,
        controller,
        default_visibility_filter,
        opts[:additional_visibility_filters] || {},
        opts[:inline_relations_depth] || 0,
      )

      prev_url = url(controller, path, paginated.prev_page, page_size, opts, request_params) if paginated.prev_page
      next_url = url(controller, path, paginated.next_page, page_size, opts, request_params) if paginated.next_page

      opts[:max_inline] ||= PreloadedObjectSerializer::MAX_INLINE_DEFAULT
      resources = dataset.all.map { |obj| @serializer.serialize(controller, obj, opts) }

      Yajl::Encoder.encode({
        :total_results => paginated.pagination_record_count,
        :total_pages   => paginated.page_count,
        :prev_url      => prev_url,
        :next_url      => next_url,
        :resources     => resources,
      }, :pretty => true)
    end

    private

    def default_visibility_filter
      user = VCAP::CloudController::SecurityContext.current_user
      admin = VCAP::CloudController::SecurityContext.admin?
      proc { |ds| ds.filter(ds.model.user_visibility(user, admin)) }
    end

    def url(controller, path, page, page_size, opts, request_params)
      params = {
        'page' => page,
        'results-per-page' => page_size,
      }

      if depth = opts[:inline_relations_depth]
        params['inline-relations-depth'] = depth
      end

      params['q'] = opts[:q] if opts[:q]

      controller.preserve_query_parameters.each do |preseved_param|
        params[preseved_param] = request_params[preseved_param] if request_params[preseved_param]
      end

      uri = Addressable::URI.parse(path)
      uri.query_values = params
      uri.normalize.request_uri
    end
  end
end
