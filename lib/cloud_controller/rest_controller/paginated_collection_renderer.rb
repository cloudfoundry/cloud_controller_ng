require 'addressable/uri'

module VCAP::CloudController::RestController
  class PaginatedCollectionRenderer
    def self.render_json(controller, ds, path, opts, request_params)
      new(controller, ds, path, opts, request_params, PreloadedObjectSerializer.new).render_json
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
    def initialize(controller, ds, path, opts, request_params, serializer)
      page      = opts[:page] || 1
      page_size = opts[:results_per_page] || 50
      criteria  = opts[:order_by] || :id

      @paginated = ds.order_by(criteria).extension(:pagination).paginate(page, page_size)

      @eager_loader = SecureEagerLoader.new
      @serializer = serializer

      @controller = controller
      @path = path
      @opts = opts
      @request_params = request_params

      @opts[:max_inline] ||= PreloadedObjectSerializer::MAX_INLINE_DEFAULT
    end

    def render_json
      Yajl::Encoder.encode({
        :total_results => @paginated.pagination_record_count,
        :total_pages   => @paginated.page_count,
        :prev_url      => @paginated.prev_page ? url(@paginated.prev_page) : nil,
        :next_url      => @paginated.next_page ? url(@paginated.next_page) : nil,
        :resources     => resources,
      }, :pretty => true)
    end

    private

    def resources
      user = VCAP::CloudController::SecurityContext.current_user
      admin = VCAP::CloudController::SecurityContext.admin?
      default_visibility_filter = proc { |ds| ds.filter(ds.model.user_visibility(user, admin)) }

      dataset = @eager_loader.eager_load_dataset(
        @paginated,
        @controller,
        default_visibility_filter,
        @opts[:additional_visibility_filters] || {},
        @opts[:inline_relations_depth] || 0,
      )

      dataset.all.map { |obj| @serializer.serialize(@controller, obj, @opts) }
    end

    def url(page)
      params = {
        'page' => page,
        'results-per-page' => @paginated.page_size
      }

      if depth = @opts[:inline_relations_depth]
        params['inline-relations-depth'] = depth
      end

      params['q'] = @opts[:q] if @opts[:q]

      @controller.preserve_query_parameters.each do |preseved_param|
        params[preseved_param] = @request_params[preseved_param] if @request_params[preseved_param]
      end

      uri = Addressable::URI.parse(@path)
      uri.query_values = params
      uri.normalize.request_uri
    end
  end
end
