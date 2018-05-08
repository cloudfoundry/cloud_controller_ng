require 'mappers/order_by_mapper'

module VCAP::CloudController
  module Presenters
    module V3
      class PaginatedListPresenter
        def initialize(presenter:, paginated_result:, path:, message: nil, show_secrets: false, decorators: [])
          @presenter = presenter
          @paginated_result = paginated_result
          @path         = path
          @message      = message
          @show_secrets = show_secrets
          @decorators = decorators
        end

        def to_hash
          hash = {
            pagination: present_pagination_hash(@message),
            resources:  presented_resources
          }

          @decorators.reduce(hash) { |memo, d| d.decorate(memo, @paginated_result.records) }
        end

        def present_pagination_hash(filters=nil)
          pagination_options = @paginated_result.pagination_options
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

          last_page     = (@paginated_result.total.to_f / pagination_options.per_page.to_f).ceil
          last_page     = 1 if last_page < 1
          previous_page = pagination_options.page - 1
          next_page     = pagination_options.page + 1

          order_params  = OrderByMapper.to_param_hash(pagination_options.order_by, pagination_options.order_direction)
          filter_params = filters.nil? ? {} : filters.to_param_hash
          params        = { per_page: pagination_options.per_page }.merge(order_params).merge(filter_params)

          first_uri    = url_builder.build_url(path: @path, query: params.merge({ page: 1 }).to_query)
          last_uri     = url_builder.build_url(path: @path, query: params.merge({ page: last_page }).to_query)
          next_uri     = url_builder.build_url(path: @path, query: params.merge({ page: next_page }).to_query)
          previous_uri = url_builder.build_url(path: @path, query: params.merge({ page: previous_page }).to_query)

          {
            total_results: @paginated_result.total,
            total_pages:   last_page,

            first:         { href: first_uri },
            last:          { href: last_uri },
            next:          next_page <= last_page ? { href: next_uri } : nil,
            previous:      previous_page > 0 ? { href: previous_uri } : nil
          }
        end

        private

        def presented_resources
          @paginated_result.records.map do |resource|
            @presenter.new(resource, show_secrets: @show_secrets, censored_message: BasePresenter::REDACTED_LIST_MESSAGE).to_hash
          end
        end
      end
    end
  end
end
