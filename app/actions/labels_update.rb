require 'models/helpers/metadata_helpers'

module VCAP::CloudController
  module LabelsUpdate
    class << self
      def update(resource, labels, label_klass, destroy_nil: true)
        starting_label_count_for_resource = label_klass.where(resource_guid: resource.guid).count

        labels ||= {}
        labels.each do |label_key, label_value|
          label_key = label_key.to_s
          prefix, name = VCAP::CloudController::MetadataHelpers.extract_prefix(label_key)
          if label_value.nil? && destroy_nil
            label_klass.find(resource_guid: resource.guid, key_prefix: prefix, key_name: name).try(:destroy)
            next
          end
          label = label_klass.find_or_create(resource_guid: resource.guid, key_prefix: prefix, key_name: name)
          label.update(value: label_value)
        end

        ending_label_count_for_resource = label_klass.where(resource_guid: resource.guid).count
        validate_max_label_limit!(labels, starting_label_count_for_resource, ending_label_count_for_resource)
        labels
      end

      private

      def validate_max_label_limit!(labels, starting_label_count, ending_label_count)
        if starting_label_count < ending_label_count && ending_label_count > max_labels_per_resource
          raise CloudController::Errors::ApiError.new_from_details('LabelLimitExceeded', labels.size, max_labels_per_resource)
        end
      end

      def max_labels_per_resource
        VCAP::CloudController::Config.config.get(:max_labels_per_resource)
      end
    end
  end
end
