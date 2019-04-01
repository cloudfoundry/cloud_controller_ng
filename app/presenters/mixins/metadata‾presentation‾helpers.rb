require 'models/helpers/label_helpers'

module VCAP::CloudController::Presenters::Mixins
  module MetadataPresentationHelpers
    def hashified_labels(labels)
      labels.each_with_object({}) do |label, memo|
        key = [label.key_prefix, label.key_name].compact.join(VCAP::CloudController::LabelHelpers::KEY_SEPARATOR)
        memo[key] = label.value
      end
    end

    def hashified_annotations(annotations)
      annotations.each_with_object({}) do |annotation, memo|
        memo[annotation.key] = annotation.value
      end
    end
  end
end
