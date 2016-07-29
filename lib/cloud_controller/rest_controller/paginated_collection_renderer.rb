require 'addressable/uri'
require 'cloud_controller/rest_controller/order_applicator'

module VCAP::CloudController::RestController
  class PaginatedCollectionRenderer
    attr_reader :collection_transformer

    def initialize(eager_loader, serializer, opts)
      @eager_loader = eager_loader
      @serializer = serializer

      @max_results_per_page = opts.fetch(:max_results_per_page)
      @default_results_per_page = opts.fetch(:default_results_per_page)

      @max_inline_relations_depth = opts.fetch(:max_inline_relations_depth)
      @default_inline_relations_depth = 0

      @collection_transformer = opts[:collection_transformer]
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
    # @option opts [Boolean] :pretty Controls pretty formatting of the encoded
    # json.  Defaults to true.
    #
    # @option opts [Integer] :inline_relations_depth Depth to recursively
    # expand relationships in addition to providing the URLs.
    #
    # @option opts [Integer] :max_inline Maximum number of objects to
    # expand inline in a relationship.
    def render_json(controller, ds, path, opts, request_params)
      page = opts[:page] || 1
      order_applicator = OrderApplicator.new(opts)
      order_direction = opts[:order_direction] || 'asc'

      page_size = opts[:results_per_page] || @default_results_per_page
      if page_size > @max_results_per_page
        raise CloudController::Errors::ApiError.new_from_details('BadQueryParameter', "results_per_page must be <= #{@max_results_per_page}")
      end

      inline_relations_depth = opts[:inline_relations_depth] || @default_inline_relations_depth
      if inline_relations_depth > @max_inline_relations_depth
        raise CloudController::Errors::ApiError.new_from_details('BadQueryParameter', "inline_relations_depth must be <= #{@max_inline_relations_depth}")
      end

      ordered_dataset = order_applicator.apply(ds)
      paginated_dataset = ordered_dataset.extension(:pagination).paginate(page, page_size)

      if paginated_dataset.prev_page
        prev_url = url(controller, path, paginated_dataset.prev_page, page_size, order_direction, opts, request_params)
      end

      if paginated_dataset.next_page
        next_url = url(controller, path, paginated_dataset.next_page, page_size, order_direction, opts, request_params)
      end

      opts[:max_inline] ||= ::CloudController::Presenters::V2::RelationsPresenter::MAX_INLINE_DEFAULT
      orphans = opts[:orphan_relations] == 1 ? {} : nil

      resources = fetch_and_process_records(paginated_dataset, controller, inline_relations_depth, orphans, opts)

      result = {
         total_results: paginated_dataset.pagination_record_count,
         total_pages: paginated_dataset.page_count,
         prev_url: prev_url,
         next_url: next_url,
         resources: resources,
      }

      if orphans
        result[:orphans] = orphans
      end

      MultiJson.dump(result, pretty: true)
    end

    private

    def fetch_and_process_records(paginated_dataset, controller, inline_relations_depth, orphans, opts)
      dataset = @eager_loader.eager_load_dataset(
        paginated_dataset,
        controller,
        default_visibility_filter,
        opts[:additional_visibility_filters] || {},
        inline_relations_depth,
      )

      dataset_records = dataset.all

      transform_opts = opts[:transform_opts] || {}
      collection_transformer.transform(dataset_records, transform_opts) if collection_transformer

      dataset_records.map { |obj| @serializer.serialize(controller, obj, opts, orphans) }
    end

    def default_visibility_filter
      user = VCAP::CloudController::SecurityContext.current_user
      admin_override = VCAP::CloudController::SecurityContext.admin? || VCAP::CloudController::SecurityContext.admin_read_only?
      proc { |ds| ds.filter(ds.model.user_visibility(user, admin_override)) }
    end

    def url(controller, path, page, page_size, order_direction, opts, request_params)
      params = {
          'page' => page,
          'results-per-page' => page_size,
          'order-direction' => order_direction
      }

      depth = opts[:inline_relations_depth]

      if depth
        params['inline-relations-depth'] = depth
      end

      params['q'] = opts[:q] if opts[:q]
      params['orphan-relations'] = opts[:orphan_relations] if opts[:orphan_relations]
      params['exclude-relations'] = opts[:exclude_relations] if opts[:exclude_relations]
      params['include-relations'] = opts[:include_relations] if opts[:include_relations]

      controller.preserve_query_parameters.each do |preserved_param|
        params[preserved_param] = request_params[preserved_param] if request_params[preserved_param]
      end

      uri = Addressable::URI.parse(path)
      uri.query_values = params
      uri.normalize.request_uri
    end
  end
end
