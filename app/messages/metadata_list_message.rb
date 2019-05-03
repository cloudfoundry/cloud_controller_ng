require 'messages/list_message'
require 'messages/validators/label_selector_requirement_validator'

module VCAP::CloudController
  class MetadataListMessage < ListMessage
    def self.register_allowed_keys(allowed_keys)
      super(allowed_keys + [:label_selector])
    end

    def self.label_selector_requested?
      @label_selector_requested ||= proc { |a| a.requested?(:label_selector) }
    end

    validates_with LabelSelectorRequirementValidator, if: label_selector_requested?
  end
end
