require 'models/helpers/metadata_helpers'

module VCAP::CloudController::Presenters::Mixins
  module MetadataPresentationHelpers
    extend ActiveSupport::Concern

    class_methods do
      def associated_resources
        [
          :labels,
          :annotations
        ]
      end
    end

    def hashified_labels(labels)
      hashified_metadata(labels)
    end

    def hashified_annotations(annotations)
      hashified_metadata(annotations)
    end

    private

    def hashified_metadata(metadata)
      metadata.each_with_object({}) do |m, memo|
        key = [m.key_prefix, m.key_name].compact.join(VCAP::CloudController::MetadataHelpers::KEY_SEPARATOR)
        memo[key] = m.value
      end
    end
  end
end
