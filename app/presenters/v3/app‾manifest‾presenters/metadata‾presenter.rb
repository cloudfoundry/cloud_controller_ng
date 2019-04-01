require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController
  module Presenters
    module V3
      module AppManifestPresenters
        class MetadataPresenter
          include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

          def to_hash(app:, **_)
            metadata = {}
            metadata[:labels] = hashified_labels(app.labels) unless app.labels.empty?
            metadata[:annotations] = hashified_annotations(app.annotations) unless app.annotations.empty?

            metadata.empty? ? {} : { metadata: metadata }
          end
        end
      end
    end
  end
end
