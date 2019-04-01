require 'active_model'
require 'models/helpers/label_helpers'
require 'messages/label_validator_helper'

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
      return VCAP::CloudController::LabelError.error(INVALID_LABEL_SELECTOR_ERROR) if requirement.nil?

      res = LabelValidatorHelper.valid_key?(requirement.key)
      return res unless res.is_valid?

      requirement.values.each do |v|
        res = LabelValidatorHelper.valid_value?(v)
        return res unless res.is_valid?
      end

      VCAP::CloudController::LabelError.none
    end
  end
end
