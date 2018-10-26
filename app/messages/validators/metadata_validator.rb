require 'active_model'
require 'models/helpers/label_helpers'
require 'cloud_controller/domain_decorator'
require 'messages/label_validator_helper'

module VCAP::CloudController::Validators
  class MetadataValidator < ActiveModel::Validator
    def validate(record)
      labels = record.labels
      return unless labels

      unless labels.is_a? Hash
        record.errors.add(:metadata, "'labels' is not a hash")
        return
      end

      labels.each do |label_key, label_value|
        validate_label_key(label_key, record)
        validate_label_value(label_value, record)
      end
    end

    private

    def validate_label_key(label_key, record)
      label_key = label_key.to_s

      unless LabelValidatorHelper.valid_key_presence?(label_key)
        record.errors.add(:metadata, 'label key cannot be empty string')
        return
      end

      unless LabelValidatorHelper.valid_key_format?(label_key)
        record.errors.add(:metadata, "label key has more than one '/'")
      end

      prefix, name = VCAP::CloudController::LabelHelpers.extract_prefix(label_key)
      validate_prefix(prefix, record)

      unless LabelValidatorHelper.valid_key_presence?(name)
        record.errors.add(:metadata, 'label key cannot be empty string')
        return
      end

      validate_common_label_syntax(name, 'key', record)
    end

    def validate_prefix(prefix, record)
      return if prefix.nil?

      unless LabelValidatorHelper.valid_prefix_format?(prefix)
        record.errors.add(:metadata, "label prefix '#{prefix}' must be in valid dns format")
      end

      unless LabelValidatorHelper.valid_prefix_size?(prefix)
        record.errors.add(:metadata, "label prefix '#{prefix[0...8]}...' is greater than #{LabelValidatorHelper::MAX_PREFIX_SIZE} characters")
      end
    end

    def validate_label_value(label_value, record)
      return true if label_value.nil?
      validate_common_label_syntax(label_value, 'value', record)
    end

    def validate_common_label_syntax(key_or_value, type, record)
      unless LabelValidatorHelper.valid_characters?(key_or_value)
        record.errors.add(:metadata, "label #{type} '#{key_or_value}' contains invalid characters")
      end

      unless LabelValidatorHelper.start_end_alphanumeric?(key_or_value)
        record.errors.add(:metadata, "label #{type} '#{key_or_value}' starts or ends with invalid characters")
      end

      unless LabelValidatorHelper.valid_size?(key_or_value)
        record.errors.add(:metadata, "label #{type} '#{key_or_value[0...8]}...' is greater than #{LabelValidatorHelper::MAX_LABEL_SIZE} characters")
      end
    end
  end
end
