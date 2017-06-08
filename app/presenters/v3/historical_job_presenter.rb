require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class HistoricalJobPresenter < BasePresenter
        def to_hash
          {
            operation: job.operation,
            state:     job.state,
            links:     build_links
          }
        end

        private

        def job
          @resource
        end

        def build_links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

          {
            self: { href: url_builder.build_url(path: "/v3/jobs/#{job.guid}") }
          }
        end
      end
    end
  end
end
