require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController
  module Presenters
    module V3
      class IsolationSegmentPresenter < BasePresenter
        include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

        def to_hash
          {
            guid: isolation_segment.guid,
            created_at: isolation_segment.created_at,
            updated_at: isolation_segment.updated_at,
            name: isolation_segment.name,
            metadata: {
              labels: hashified_labels(isolation_segment.labels),
              annotations: hashified_annotations(isolation_segment.annotations)
            },
            links: build_links,
          }
        end

        private

        def isolation_segment
          @resource
        end

        def build_links
          {
            self: { href: url_builder.build_url(path: "/v3/isolation_segments/#{isolation_segment.guid}") },
            organizations: { href: url_builder.build_url(path: "/v3/isolation_segments/#{isolation_segment.guid}/organizations") },
          }
        end
      end
    end
  end
end
