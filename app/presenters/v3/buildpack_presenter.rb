require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController::Presenters::V3
  class BuildpackPresenter < BasePresenter
    include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

    def to_hash
      {
        guid: buildpack.guid,
        created_at: buildpack.created_at,
        updated_at: buildpack.updated_at,
        name: buildpack.name,
        stack: buildpack.stack,
        state: buildpack.state,
        filename: buildpack.filename,
        position: buildpack.position,
        enabled: buildpack.enabled,
        locked: buildpack.locked,
        metadata: {
          labels: hashified_labels(buildpack.labels),
          annotations: hashified_annotations(buildpack.annotations),
        },
        links: build_links,
      }
    end

    class << self
      # :labels and :annotations come from MetadataPresentationHelpers
      def associated_resources
        super
      end
    end

    private

    def buildpack
      @resource
    end

    def build_links
      {
        self: {
          href: url_builder.build_url(path: "/v3/buildpacks/#{buildpack.guid}")
        },
        upload: {
          href: url_builder.build_url(path: "/v3/buildpacks/#{buildpack.guid}/upload"),
          method: 'POST'
        }
      }
    end
  end
end
