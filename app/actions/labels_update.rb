require 'models/helpers/label_helpers'

module VCAP::CloudController
  module LabelsUpdate
    class TooManyLabels < StandardError; end

    class << self
      def update(resource, labels, label_klass)
        labels ||= {}
        starting_size = label_klass.where(resource_guid: resource.guid).count
        labels.each do |label_key, label_value|
          label_key = label_key.to_s
          prefix, name = VCAP::CloudController::LabelHelpers.extract_prefix(label_key)
          if label_value.nil?
            label_klass.find(resource_guid: resource.guid, key_prefix: prefix, key_name: name).try(:destroy)
            next
          end
          label = label_klass.find_or_create(resource_guid: resource.guid, key_prefix: prefix, key_name: name)
          label.update(value: label_value.to_s)
        end
        max_labels = VCAP::CloudController::Config.config.get(:max_labels_per_resource)
        current_size = resource.class.find(guid: resource.guid).labels.size
        if starting_size < current_size && current_size > max_labels
          raise TooManyLabels.new("Failed to add #{labels.size} labels because it would exceed maximum of #{max_labels}")
        end
      end
    end
  end
end
