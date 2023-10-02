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

          if label_value.nil? && destroy_nil # Delete Label
            label_klass.where(resource_guid: resource.guid, key_name: name).where(Sequel.or([[:key_prefix, prefix], [:key_prefix, prefix.to_s]])).try(:destroy)
            next
          end

          begin
            tries ||= 2
            label_klass.db.transaction(savepoint: true) do
              label = label_klass.where(resource_guid: resource.guid, key_name: name).where(Sequel.or([[:key_prefix, prefix], [:key_prefix, prefix.to_s]])).first
              label ||= label_klass.create(resource_guid: resource.guid, key_name: name, key_prefix: prefix)
              label.update(value: label_value)
            end
          rescue Sequel::UniqueConstraintViolation => e
            if (tries -= 1).positive?
              retry
            else
              v3_api_error!(:UniquenessError, e.message)
            end
          end
        end

        ending_label_count_for_resource = label_klass.where(resource_guid: resource.guid).count
        validate_max_label_limit!(labels, starting_label_count_for_resource, ending_label_count_for_resource)
        labels
      end

      private

      def validate_max_label_limit!(labels, starting_label_count, ending_label_count)
        return unless starting_label_count < ending_label_count && ending_label_count > max_labels_per_resource

        raise CloudController::Errors::ApiError.new_from_details('LabelLimitExceeded', labels.size, max_labels_per_resource)
      end

      def max_labels_per_resource
        VCAP::CloudController::Config.config.get(:max_labels_per_resource)
      end
    end
  end
end
