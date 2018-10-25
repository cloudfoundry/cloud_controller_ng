require 'models/helpers/label_helpers'

module VCAP::CloudController
  class AppLabelsUpdate
    class << self
      def update(app, labels)
        labels ||= {}
        labels.each do |label_key, label_value|
          label_key = label_key.to_s
          prefix, name = VCAP::CloudController::LabelHelpers.extract_prefix(label_key)
          app_label = AppLabelModel.find_or_create(app_guid: app.guid, key_prefix: prefix, key_name: name)
          app_label.update(value: label_value.to_s)
        end
      end
    end
  end
end
