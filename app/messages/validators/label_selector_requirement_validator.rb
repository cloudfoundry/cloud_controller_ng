require 'active_model'
require 'models/helpers/metadata_helpers'
require 'messages/metadata_validator_helper'

module VCAP::CloudController::Validators
  class LabelSelectorRequirementValidator < ActiveModel::Validator
    MISSING_LABEL_SELECTOR_ERROR = 'Missing label_selector value'.freeze
    INVALID_LABEL_SELECTOR_ERROR = 'Invalid label_selector value'.freeze

    def validate(record)
      if record.requirements.empty?
        record.errors[:base] << MISSING_LABEL_SELECTOR_ERROR
        return
      end

      record.requirements.each do |r|
        res = valid_requirement?(r)
        record.errors[:base] << res.message unless res.is_valid?
      end
    end

    private

    def valid_requirement?(requirement)
      return VCAP::CloudController::MetadataError.error(INVALID_LABEL_SELECTOR_ERROR) if requirement.nil?

      res = MetadataValidatorHelper.new(key: requirement.key).key_error
      return res unless res.is_valid?

      requirement.values.each do |v|
        res = MetadataValidatorHelper.new(value: v).value_error
        return res unless res.is_valid?
      end

      VCAP::CloudController::MetadataError.none
    end
  end
end
