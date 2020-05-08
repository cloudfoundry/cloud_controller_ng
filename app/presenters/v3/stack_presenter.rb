require 'presenters/mixins/metadata_presentation_helpers'
require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class StackPresenter < BasePresenter
    include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

    def to_hash
      {
        guid: stack.guid,
        created_at: stack.created_at,
        updated_at: stack.updated_at,
        name: stack.name,
        description: stack.description,
        metadata: {
          labels: hashified_labels(stack.labels),
          annotations: hashified_annotations(stack.annotations),
        },
        links: build_links
      }
    end

    private

    def stack
      @resource
    end

    def build_links
      {
        self: {
          href: url_builder.build_url(path: "/v3/stacks/#{stack.guid}")
        },
      }
    end
  end
end
