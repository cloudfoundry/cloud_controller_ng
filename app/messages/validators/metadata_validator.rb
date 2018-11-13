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
        unless labels.is_a? Hash
          record.errors.add(:metadata, "'labels' is not a hash")
          return
        end

        labels.each do |label_key, label_value|
          validate_label_key(label_key, record)
          validate_label_value(label_value, record)
        end
      end

      if annotations
        unless annotations.is_a? Hash
          record.errors.add(:metadata, "'annotations' is not a hash")
          return
        end
        annotations.each do |annotation_key, annotation_value|
          validate_annotation_key(annotation_key, record)
          validate_annotation_value(annotation_value, record)
        end
      end
    end

    private

    def validate_label_key(label_key, record)
      label_key = label_key.to_s

      label_result = LabelValidatorHelper.valid_key_presence?(label_key)
      unless label_result.is_valid?
        record.errors.add(:metadata, label_result.message)
        return
      end

      label_result = LabelValidatorHelper.valid_key_format?(label_key)
      record.errors.add(:metadata, label_result.message) unless label_result.is_valid?

      prefix, name = VCAP::CloudController::LabelHelpers.extract_prefix(label_key)
      validate_prefix(prefix, record)

      label_result = LabelValidatorHelper.valid_key_presence?(name)
      unless label_result.is_valid?
        record.errors.add(:metadata, label_result.message)
        return
      end

      validate_common_label_syntax(name, 'key', record)
    end

    def validate_prefix(prefix, record)
      return if prefix.nil?
      [:valid_prefix_format?, :valid_prefix_size?, :is_not_reserved].each do |method|
        label_result = LabelValidatorHelper.send(method, prefix)
        record.errors.add(:metadata, label_result.message) unless label_result.is_valid?
      end
    end

    def validate_label_value(label_value, record)
      return true if label_value.nil? || label_value == ''
      validate_common_label_syntax(label_value, 'value', record)
    end

    def validate_common_label_syntax(key_or_value, type, record)
      [:valid_characters?, :start_end_alphanumeric?, :valid_size?].each do |method|
        label_result = LabelValidatorHelper.send(method, key_or_value)
        unless label_result.is_valid?
          record.errors.add(:metadata, "#{type} error: #{label_result.message}")
        end
      end
    end

    def validate_annotation_key(annotation_key, record)
      if annotation_key.size > MAX_ANNOTATION_KEY_SIZE
        record.errors.add(:metadata, "key error: annotation '#{annotation_key[0...8]}...' is greater than 1000 characters")
      end
      if annotation_key.size == 0
        record.errors.add(:metadata, 'annotations key cannot be empty string')
      end
    end

    def validate_annotation_value(annotation_value, record)
      if annotation_value.size > MAX_ANNOTATION_VALUE_SIZE
        record.errors.add(:metadata, "value error: annotation '#{annotation_value[0...8]}...' is greater than 5000 characters")
      end
    end
  end
end
