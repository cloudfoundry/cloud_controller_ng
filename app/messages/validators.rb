require 'active_model'
require 'utils/uri_utils'
require 'models/helpers/health_check_types'
require 'cloud_controller/domain_decorator'

module VCAP::CloudController::Validators
  module StandaloneValidator
    def validate_each(*args)
      new(attributes: [nil]).validate_each(*args)
    end
  end

  class ArrayValidator < ActiveModel::EachValidator
    def validate_each(record, attr_name, value)
      record.errors.add(attr_name, 'must be an array') unless value.is_a? Array
    end
  end

  class StringValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      record.errors.add attribute, 'must be a string' unless value.is_a?(String)
    end
  end

  class BooleanValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      record.errors.add attribute, 'must be a boolean' unless boolean?(value)
    end

    private

    def boolean?(value)
      [true, false].include? value
    end
  end

  class HashValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      record.errors.add attribute, 'must be a hash' unless value.is_a?(Hash)
    end
  end

  class GuidValidator < ActiveModel::EachValidator
    extend StandaloneValidator

    def validate_each(record, attribute, value)
      record.errors.add attribute, 'must be a string' unless value.is_a?(String)
      record.errors.add attribute, 'must be between 1 and 200 characters' unless value.is_a?(String) && (1..200).cover?(value.size)
    end
  end

  class UriValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      record.errors.add attribute, 'must be a valid URI' unless UriUtils.is_uri?(value)
    end
  end

  class UriPathValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      record.errors.add attribute, 'must be a valid URI path' unless UriUtils.is_uri_path?(value)
    end
  end

  class EnvironmentVariablesValidator < ActiveModel::EachValidator
    extend StandaloneValidator

    def validate_each(record, attribute, value)
      if !value.is_a?(Hash)
        record.errors.add(attribute, 'must be a hash')
      else
        value.each_key do |key|
          if ![String, Symbol].include?(key.class)
            record.errors.add(attribute, 'key must be a string')
          elsif key.length < 1
            record.errors.add(attribute, 'key must be a minimum length of 1')
          elsif key.match?(/\AVCAP_/i)
            record.errors.add(attribute, 'cannot start with VCAP_')
          elsif key.match?(/\AVMC/i)
            record.errors.add(attribute, 'cannot start with VMC_')
          elsif key.match?(/\APORT\z/i)
            record.errors.add(attribute, 'cannot set PORT')
          end
        end
      end
    end
  end

  class HealthCheckValidator < ActiveModel::Validator
    def validate(record)
      if record.health_check_type != VCAP::CloudController::HealthCheckTypes::HTTP
        record.errors.add(:health_check_type, 'must be "http" to set a health check HTTP endpoint')
      end
    end
  end

  class LifecycleValidator < ActiveModel::Validator
    def validate(record)
      data_message = {
        VCAP::CloudController::Lifecycles::BUILDPACK => VCAP::CloudController::BuildpackLifecycleDataMessage,
        VCAP::CloudController::Lifecycles::DOCKER => VCAP::CloudController::DockerLifecycleDataMessage,
      }

      lifecycle_data_message_class = data_message[record.lifecycle_type]
      if lifecycle_data_message_class.nil?
        record.errors[:lifecycle_type].concat ["is not included in the list: #{data_message.keys.join(', ')}"]
        return
      end

      return unless record.lifecycle_data.is_a?(Hash)

      lifecycle_data_message = lifecycle_data_message_class.new(record.lifecycle_data)
      unless lifecycle_data_message.valid?
        record.errors[:lifecycle].concat lifecycle_data_message.errors.full_messages
      end
    end
  end

  class MetadataValidator < ActiveModel::Validator
    def validate(record)
      labels = record.labels
      return unless labels
      unless labels.is_a? Hash
        record.errors.add(:metadata, "'labels' is not a hash")
        return
      end
      labels.each do |full_key, value|
        full_key = full_key.to_s
        key = full_key
        if full_key.include?('/')
          namespace, key = full_key.split('/')

          if full_key.count('/') > 1
            record.errors.add(:metadata, "label key has more than one '/'")
          end

          if !CloudController::DomainDecorator::DOMAIN_REGEX.match(namespace)
            record.errors.add(:metadata, "label namespace '#{namespace}' must be in valid dns format")
          elsif namespace.size > VCAP::CloudController::AppUpdateMessage::MAX_NAMESPACE_SIZE
            record.errors.add(:metadata, "label namespace '#{namespace[0...8]}...' is greater than #{VCAP::CloudController::AppUpdateMessage::MAX_NAMESPACE_SIZE} characters")
          end
        end

        if key.nil? || key.size == 0
          record.errors.add(:metadata, 'label key cannot be empty string')
        else
          validate_label_key_or_value(key, 'key', record)
        end

        validate_label_key_or_value(value, 'value', record)
      end
    end

    private

    VALID_CHAR_REGEX = /[^\w\-\.\_]/
    ALPHANUMERIC_START_END_REGEX = /\A(?=[a-zA-Z\d]).*[a-zA-Z\d]\z/

    def validate_label_key_or_value(key_or_value, type, record)
      if VALID_CHAR_REGEX.match?(key_or_value)
        record.errors.add(:metadata, "label #{type} '#{key_or_value}' contains invalid characters")
      elsif !ALPHANUMERIC_START_END_REGEX.match?(key_or_value)
        record.errors.add(:metadata, "label #{type} '#{key_or_value}' starts or ends with invalid characters")
      end

      if key_or_value.size > VCAP::CloudController::AppUpdateMessage::MAX_LABEL_SIZE
        record.errors.add(:metadata, "label #{type} '#{key_or_value[0...8]}...' is greater than #{VCAP::CloudController::AppUpdateMessage::MAX_LABEL_SIZE} characters")
      end
    end
  end

  class RelationshipValidator < ActiveModel::Validator
    def validate(record)
      if !record.relationships.is_a?(Hash)
        record.errors[:relationships].concat ["'relationships' is not a hash"]
        return
      end

      rel = record.relationships_message

      if !rel.valid?
        record.errors[:relationships].concat(rel.errors.full_messages)
      end
    end
  end

  class DataValidator < ActiveModel::Validator
    def validate(record)
      return if !record.data.is_a?(Hash)

      data = record.class::Data.new(record.data.symbolize_keys)

      if !data.valid?
        record.errors[:data].concat(data.errors.full_messages)
      end
    end
  end

  class ToOneRelationshipValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, relationship)
      if has_correct_structure?(relationship)
        validate_guid(record, attribute, relationship) if relationship[:data]
      else
        record.errors.add(attribute, error_message(attribute))
      end
    end

    private

    def error_message(attribute)
      "must be structured like this: \"#{attribute}: {\"data\": {\"guid\": \"valid-guid\"}}\""
    end

    def validate_guid(record, attribute, relationship)
      VCAP::CloudController::BaseMessage::GuidValidator.
        validate_each(record, "#{attribute} Guid", relationship.values.first.values.first)
    end

    def has_correct_structure?(relationship)
      relationship.is_a?(Hash) &&
        had_data_key(relationship) &&
        data_has_correct_structure?(relationship[:data])
    end

    def had_data_key(relationship)
      relationship.keys == [:data]
    end

    def data_has_correct_structure?(data)
      data.nil? || (data.is_a?(Hash) && has_guid_key(data))
    end

    def has_guid_key(data)
      (data.keys == [:guid])
    end
  end

  class ToManyRelationshipValidator < ActiveModel::EachValidator
    def error_message(attribute)
      "must be structured like this: \"#{attribute}: [{\"guid\": \"valid-guid\"},{\"guid\": \"valid-guid\"}]\""
    end

    def validate_each(record, attribute, value)
      if has_correct_structure?(value)
        validate_guids(record, attribute, value)
      else
        record.errors.add(attribute, error_message(attribute))
      end
    end

    def validate_guids(record, attribute, value)
      guids = value.map(&:values).flatten
      guids.each_with_index do |guid, idx|
        VCAP::CloudController::BaseMessage::GuidValidator.
          validate_each(record, "#{attribute} Guid #{idx}", guid)
      end
    end

    def has_correct_structure?(value)
      (value.is_a?(Array) && value.all? { |hsh| is_a_guid_hash?(hsh) })
    end

    def is_a_guid_hash?(hsh)
      (hsh.keys.map(&:to_s) == ['guid'])
    end
  end
end
