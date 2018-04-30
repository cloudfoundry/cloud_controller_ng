require 'presenters/v3/pagination_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class PaginatedListPresenter
        def initialize(presenter:, dataset:, path:, message: nil, show_secrets: false, decorators: [])
          @dataset      = dataset
          @path         = path
          @message      = message
          @show_secrets = show_secrets
          @decorators = decorators
          @presenter = presenter
        end

        def to_hash
          hash = {
            pagination: PaginationPresenter.new.present_pagination_hash(paginator, @path, @message),
            resources:  presented_resources
          }

          @decorators.reduce(hash) { |memo, d| d.decorate(memo, paginator.records) }
        end

        private

        def presented_resources
          paginator.records.map do |resource|
            @presenter.new(resource, show_secrets: @show_secrets, censored_message: BasePresenter::REDACTED_LIST_MESSAGE).to_hash
          end
        end

        def paginator
          @paginator ||= SequelPaginator.new.get_page(@dataset, @message.try(:pagination_options))
        end
      end
    end
  end
end
