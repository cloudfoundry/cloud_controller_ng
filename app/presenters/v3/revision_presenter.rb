require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController
  module Presenters
    module V3
      class RevisionPresenter < BasePresenter
        include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

        def to_hash
          {
            guid: revision.guid,
            version: revision.version,
            droplet: {
              guid: revision.droplet_guid,
            },
            created_at: revision.created_at,
            updated_at: revision.updated_at,
            links: build_links,
            metadata: {
              labels: hashified_labels(revision.labels),
              annotations: hashified_annotations(revision.annotations),
            }
          }
        end

        private

        def revision
          @resource
        end

        def build_links
          url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

          {
            self: {
              href: url_builder.build_url(path: "/v3/apps/#{revision.app_guid}/revisions/#{revision.guid}")
            }
          }
        end
      end
    end
  end
end
