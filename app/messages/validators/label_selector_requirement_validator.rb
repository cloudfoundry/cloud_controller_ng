require 'active_model'
require 'models/helpers/metadata_helpers'
require 'messages/metadata_validator_helper'

module VCAP::CloudController::Validators
  class LabelSelectorRequirementValidator < ActiveModel::Validator
    def validate(record)
      parser = record.label_selector_parser
      if !parser.errors.empty?
        parser.errors.each { |err| record.errors[:base] << err }
        return
      end

      # TODO:  These should be warnings because we're just testing bad data, but not adding it
      record.requirements.each do |r|
        res = valid_requirement?(r)
        record.errors[:base] << res.message unless res.is_valid?
      end
    end

    private

    def valid_requirement?(requirement)
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
