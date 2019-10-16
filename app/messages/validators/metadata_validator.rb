require 'active_model'
require 'models/helpers/metadata_helpers'
require 'cloud_controller/domain_decorator'
require 'messages/metadata_validator_helper'

module VCAP::CloudController::Validators
  class MetadataValidator < ActiveModel::Validator
    MAX_ANNOTATION_VALUE_SIZE = 5000

    attr_accessor :labels, :annotations, :record

    def validate(record)
      self.record = record

      unless record.metadata.is_a? Hash
        record.errors.add(:metadata, 'must be an object')
        return
      end

      invalid_keys = record.metadata.except(:labels, :annotations).keys
      unexpected_keys = invalid_keys.map { |val| "'" << val.to_s << "'" }.join(' ')
      unless invalid_keys.empty?
        record.errors.add(:metadata, "has unexpected field(s): #{unexpected_keys}")
      end

      self.labels = record.labels
      self.annotations = record.annotations

      validate_labels if labels
      validate_annotations if annotations
    end

    private

    def validate_annotations
      return record.errors.add(:metadata, "'annotations' is not an object") unless annotations.is_a? Hash

      annotations.each do |annotation_key, annotation_value|
        helper = MetadataValidatorHelper.new(key: annotation_key, value: annotation_value)
        key_result = helper.key_error
        if annotation_value.present? && !key_result.is_valid?
          record.errors.add(:metadata, "annotation key error: #{key_result.message}")
        end
        validate_annotation_value(annotation_value, record)
      end
    end

    def validate_labels
      return record.errors.add(:metadata, "'labels' is not an object") unless labels.is_a? Hash

      labels.each do |key, value|
        helper = MetadataValidatorHelper.new(key: key, value: value)
        key_result = helper.key_error
        value_result = helper.value_error

        record.errors.add(:metadata, "label key error: #{key_result.message}") unless key_result.is_valid?
        record.errors.add(:metadata, "label value error: #{value_result.message}") unless value_result.is_valid?
      end
    end

    def validate_annotation_value(annotation_value, record)
      if !annotation_value.nil? && annotation_value.size > MAX_ANNOTATION_VALUE_SIZE
        record.errors.add(:metadata, "annotation value error: '#{annotation_value[0...8]}...' is greater than 5000 characters")
      end
    end
  end
end
