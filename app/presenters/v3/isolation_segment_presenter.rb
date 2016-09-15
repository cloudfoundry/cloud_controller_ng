require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class IsolationSegmentPresenter < BasePresenter
        def to_hash
          return_hash = {
            guid:       isolation_segment.guid,
            name:       isolation_segment.name,
            created_at: isolation_segment.created_at,
            updated_at: isolation_segment.updated_at,
          }

          return_hash[:links] = build_links if @build_links
          return_hash
        end

        private

        def isolation_segment
          @resource
        end

        def build_links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new
          {
            self:   { href: url_builder.build_url(path: "/v3/isolation_segments/#{isolation_segment.guid}") },
            organizations: { href: url_builder.build_url(path: "/v3/isolation_segments/#{isolation_segment.guid}/organizations") },
            spaces: { href: url_builder.build_url(path: "/v3/isolation_segments/#{isolation_segment.guid}/spaces") },
          }
        end
      end
    end
  end
end
