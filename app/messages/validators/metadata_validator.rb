require 'active_model'
require 'models/helpers/label_helpers'
require 'cloud_controller/domain_decorator'
require 'messages/label_validator_helper'

module VCAP::CloudController::Validators
  class MetadataValidator < ActiveModel::Validator
    MAX_ANNOTATION_KEY_SIZE = 1000
    MAX_ANNOTATION_VALUE_SIZE = 5000
    def validate(record)
      unless record.metadata.is_a? Hash
        record.errors.add(:metadata, 'must be a hash')
        return
      end

      invalid_keys = record.metadata.except(:labels, :annotations).keys
      unexpected_keys = invalid_keys.map { |val| "'" << val.to_s << "'" }.join(' ')
      unless invalid_keys.empty?
        record.errors.add(:metadata, "has unexpected field(s): #{unexpected_keys}")
      end

      labels = record.labels
      annotations = record.annotations

      if labels
        if labels.is_a? Hash
          labels.each do |label_key, label_value|
            validate_label_key(label_key, record)
            validate_label_value(label_value, record)
          end
        else
          record.errors.add(:metadata, "'labels' is not a hash")
        end
      end

      if annotations
        if annotations.is_a? Hash
          annotations.each do |annotation_key, annotation_value|
            validate_annotation_key(annotation_key, record)
            validate_annotation_value(annotation_value, record)
          end
        else
          record.errors.add(:metadata, "'annotations' is not a hash")
        end
      end
    end

    private

    def validate_label_key(label_key, record)
      label_result = LabelValidatorHelper.valid_key?(label_key.to_s)
      unless label_result.is_valid?
        record.errors.add(:metadata, "key error: #{label_result.message}")
      end
    end

    def validate_label_value(label_value, record)
      label_result = LabelValidatorHelper.valid_value?(label_value)
      unless label_result.is_valid?
        record.errors.add(:metadata, "value error: #{label_result.message}")
      end
    end

    def validate_annotation_key(annotation_key, record)
      if annotation_key.size > MAX_ANNOTATION_KEY_SIZE
        record.errors.add(:metadata, "key error: annotation '#{annotation_key[0...8]}...' is greater than 1000 characters")
      end
      if annotation_key.empty?
        record.errors.add(:metadata, 'annotations key cannot be empty string')
      end
    end

    def validate_annotation_value(annotation_value, record)
      if !annotation_value.nil? && annotation_value.size > MAX_ANNOTATION_VALUE_SIZE
        record.errors.add(:metadata, "value error: annotation '#{annotation_value[0...8]}...' is greater than 5000 characters")
      end
    end
  end
end
