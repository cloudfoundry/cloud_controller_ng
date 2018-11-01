require 'models/helpers/label_helpers'

module VCAP::CloudController
  module LabelsUpdate
    class << self
      def update(resource, labels, label_klass)
        labels ||= {}
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
      end
    end
  end
end
