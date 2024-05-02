require 'active_model'
require 'utils/uri_utils'
require 'models/helpers/health_check_types'
require 'models/helpers/metadata_error'
require 'models/helpers/metadata_helpers'
require 'models/helpers/label_selector_requirement'
require 'models/helpers/relational_operators'
require 'cloud_controller/domain_decorator'
require 'messages/metadata_validator_helper'

module VCAP::CloudController::Validators
  module StandaloneValidator
    def validate_each(*)
      new(attributes: [nil]).validate_each(*)
    end
  end

  class ArrayValidator < ActiveModel::EachValidator
    def validate_each(record, attr_name, value)
      record.errors.add(attr_name, message: 'must be an array') unless value.is_a? Array
    end
  end

  class StringValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      record.errors.add attribute, message: 'must be a string' unless value.is_a?(String)
    end
  end

  class BooleanValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      record.errors.add attribute, message: 'must be a boolean' unless boolean?(value)
    end

    private

    def boolean?(value)
      [true, false].include? value
    end
  end

  class BooleanStringValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      record.errors.add attribute, message: "must be 'true' or 'false'" unless boolean?(value)
    end

    private

    def boolean?(value)
      %w[true false].include? value
    end
  end

  class HashValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      record.errors.add attribute, message: 'must be an object' unless value.is_a?(Hash)
    end
  end

  class GuidValidator < ActiveModel::EachValidator
    extend StandaloneValidator

    def validate_each(record, attribute, value)
      record.errors.add attribute, message: 'must be a string' unless value.is_a?(String)
      record.errors.add attribute, message: 'must be between 1 and 200 characters' unless value.is_a?(String) && (1..200).cover?(value.size)
    end
  end

  class UriValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      record.errors.add attribute, message: 'must be a valid URI' unless UriUtils.is_uri?(value)
    end
  end

  class UriPathValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      record.errors.add attribute, message: 'must be a valid URI path' unless UriUtils.is_uri_path?(value)
    end
  end

  class EnvironmentVariablesValidator < ActiveModel::EachValidator
    extend StandaloneValidator

    def validate_each(record, attribute, value)
      if value.is_a?(Hash)
        value.each_key do |key|
          if [String, Symbol].exclude?(key.class)
            record.errors.add(attribute, message: 'key must be a string')
          elsif key.empty?
            record.errors.add(attribute, message: 'key must be a minimum length of 1')
          elsif key.match?(/\AVCAP_/i)
            record.errors.add(attribute, message: 'cannot start with VCAP_')
          elsif key.match?(/\AVMC/i)
            record.errors.add(attribute, message: 'cannot start with VMC_')
          elsif key.match?(/\APORT\z/i)
            record.errors.add(attribute, message: 'cannot set PORT')
          end
        end
      else
        record.errors.add(attribute, message: 'must be an object')
      end
    end
  end

  class EnvironmentVariablesStringValuesValidator < ActiveModel::EachValidator
    extend StandaloneValidator

    def validate_each(record, attribute, value)
      if value.is_a?(Hash)
        value.each do |key, inner_value|
          if [String, Symbol].exclude?(key.class)
            record.errors.add(attribute, message: 'key must be a string')
          elsif key.empty?
            record.errors.add(attribute, message: 'key must be a minimum length of 1')
          elsif key.match?(/\AVCAP_/i)
            record.errors.add(attribute, message: 'cannot start with VCAP_')
          elsif key.match?(/\AVMC/i)
            record.errors.add(attribute, message: 'cannot start with VMC_')
          elsif key.match?(/\APORT\z/i)
            record.errors.add(attribute, message: 'cannot set PORT')
          elsif [String, NilClass].exclude?(inner_value.class)
            stringified = inner_value.to_json
            record.errors.add(:base, message: "Non-string value in environment variable for key '#{key}', value '#{stringified}'")
          end
        end
      else
        record.errors.add(attribute, message: 'must be an object')
      end
    end
  end

  class FieldsValidator < ActiveModel::EachValidator
    extend StandaloneValidator

    def validate_each(record, attribute, value)
      if value.is_a?(Hash)
        allowed_resources = options[:allowed]
        value.each do |resource, keys|
          allowed_keys = allowed_resources[resource.to_s] || allowed_resources[resource.to_sym]
          if allowed_keys.nil?
            record.errors.add(attribute, message: "[#{resource}] valid resources are: #{allowed_resources.keys.map { |k| "'#{k}'" }.join(', ')}")
          elsif !keys.to_set.subset?(allowed_keys.to_set)
            record.errors.add(attribute, message: "valid keys for '#{resource}' are: #{allowed_keys.map { |i| "'#{i}'" }.join(', ')}")
          end
        end
      else
        record.errors.add(attribute, message: 'must be an object')
      end
    end
  end

  class HealthCheckValidator < ActiveModel::Validator
    def validate(record)
      return unless record.health_check_type != VCAP::CloudController::HealthCheckTypes::HTTP

      record.errors.add(:health_check_type, message: 'must be "http" to set a health check HTTP endpoint')
    end
  end

  class ReadinessHealthCheckValidator < ActiveModel::Validator
    def validate(record)
      return unless record.readiness_health_check_type != VCAP::CloudController::HealthCheckTypes::HTTP

      record.errors.add(:readiness_health_check_type, message: 'must be "http" to set a health check HTTP endpoint')
    end
  end

  class OrgVisibilityValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      return if value.nil?

      return unless value.reject { |o| o.is_a?(Hash) && o.key?(:guid) && o[:guid].is_a?(String) }.any?

      record.errors.add(attribute, message: "organizations list must be structured like this: \"#{attribute}\": [{\"guid\": \"valid-guid\"}]")
    end
  end

  class LifecycleValidator < ActiveModel::Validator
    def validate(record)
      lifecycles = VCAP::CloudController::Lifecycles
      default_lifecycle = VCAP::CloudController::Config.config.get(:default_app_lifecycle)
      lifecycle_type = record.lifecycle_type || default_lifecycle

      data_message_class_table = {
        lifecycles::BUILDPACK => VCAP::CloudController::BuildpackLifecycleDataMessage,
        lifecycles::DOCKER => VCAP::CloudController::EmptyLifecycleDataMessage,
        lifecycles::CNB => VCAP::CloudController::BuildpackLifecycleDataMessage
      }

      lifecycle_data_message_class = data_message_class_table[lifecycle_type]
      if lifecycle_data_message_class.nil?
        record.errors.add(:lifecycle_type, message: "is not included in the list: #{data_message_class_table.keys.join(', ')}")
        return
      end

      return unless record.lifecycle_data.is_a?(Hash)

      lifecycle_data_message = lifecycle_data_message_class.new(record.lifecycle_data)
      return if lifecycle_data_message.valid?

      lifecycle_data_message.errors.full_messages.each do |message|
        record.errors.add(:lifecycle, message:)
      end
    end
  end

  class DataValidator < ActiveModel::Validator
    def validate(record)
      return unless record.data.is_a?(Hash)

      data = record.class::Data.new(record.data.symbolize_keys)

      return if data.valid?

      data.errors.full_messages.each do |message|
        record.errors.add(:data, message:)
      end
    end
  end

  class RelationshipValidator < ActiveModel::Validator
    def validate(record)
      unless record.relationships.is_a?(Hash)
        record.errors.add(:relationships, message: "'relationships' is not an object")
        return
      end

      if record.relationships.empty?
        record.errors.add(:relationships, message: "'relationships' must include one or more valid relationships")
        return
      end

      rel = record.relationships_message

      return if rel.valid?

      rel.errors.full_messages.each do |message|
        record.errors.add(:relationships, message:)
      end
    end
  end

  class ToOneRelationshipValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, relationship)
      if has_correct_structure?(relationship)
        validate_guid(record, attribute, relationship) if relationship[:data]
      else
        record.errors.add(attribute, message: error_message(attribute))
      end
    end

    private

    def error_message(attribute)
      "must be structured like this: \"#{attribute}: {\"data\": {\"guid\": \"valid-guid\"}}\""
    end

    def validate_guid(record, attribute, relationship)
      VCAP::CloudController::BaseMessage::GuidValidator.
        validate_each(record, :"#{attribute}_guid", relationship.values.first.values.first)
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
      "must be structured like this: \"#{attribute}: {\"data\": [{\"guid\": \"valid-guid\"},{\"guid\": \"valid-guid\"}]}\""
    end

    def validate_each(record, attribute, value)
      if has_correct_structure?(value)
        validate_guids(record, attribute, value[:data])
      else
        record.errors.add(attribute, message: error_message(attribute))
      end
    end

    def validate_guids(record, attribute, value)
      guids = value.map(&:values).flatten
      guids.each_with_index do |guid, _idx|
        VCAP::CloudController::BaseMessage::GuidValidator.
          validate_each(record, :"#{attribute.to_s.singularize}_guids", guid)
      end
    end

    def properly_formatted_data(data)
      data.is_a?(Array) && data.all? { |hsh| is_a_guid_hash?(hsh) }
    end

    def has_correct_structure?(value)
      value.is_a?(Hash) && value[:data] && properly_formatted_data(value[:data])
    end

    def is_a_guid_hash?(hsh)
      (hsh.keys.map(&:to_s) == ['guid'])
    end
  end

  class SemverValidator < StringValidator
    def validate_each(record, attr_name, value)
      super
      record.errors.add(attr_name, message: 'must be a Semantic Version string') unless is_semver?(value)
    end

    def is_semver?(value)
      VCAP::SemverValidator.valid?(value)
    end
  end

  class TimestampValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, values)
      if values.is_a?(Array)
        values.each do |timestamp|
          opinionated_iso_8601(timestamp, record, attribute)
        end
      else
        unless values.is_a?(Hash)
          record.errors.add(attribute, message: 'relational operator and timestamp must be specified')
          return
        end

        valid_relational_operators = [
          VCAP::CloudController::RelationalOperators::LESS_THAN_COMPARATOR,
          VCAP::CloudController::RelationalOperators::GREATER_THAN_COMPARATOR,
          VCAP::CloudController::RelationalOperators::LESS_THAN_OR_EQUAL_COMPARATOR,
          VCAP::CloudController::RelationalOperators::GREATER_THAN_OR_EQUAL_COMPARATOR
        ]

        values.each do |relational_operator, timestamp|
          record.errors.add(attribute, message: "Invalid relational operator: '#{relational_operator}'") unless valid_relational_operators.include?(relational_operator)

          if timestamp.to_s.include?(',')
            record.errors.add(attribute, message: 'only accepts one value when using a relational operator')
            next
          end

          opinionated_iso_8601(timestamp, record, attribute)
        end
      end
    end

    private

    def opinionated_iso_8601(timestamp, record, attribute)
      return unless /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\Z/ !~ timestamp.to_s

      record.errors.add(attribute, message: "has an invalid timestamp format. Timestamps should be formatted as 'YYYY-MM-DDThh:mm:ssZ'")
    end
  end

  class TargetGuidsValidator < ActiveModel::Validator
    def validate(record)
      if record.target_guids.is_a? Hash
        if record.target_guids[:not].present?
          record.errors.add(:target_guids, message: 'target_guids must be an array') unless record.target_guids[:not].is_a? Array
        else
          record.errors.add(:target_guids, message: 'target_guids has an invalid operator')
        end
      elsif record.target_guids.present?
        record.errors.add(:target_guids, message: 'target_guids must be an array') unless record.target_guids.is_a? Array
      end
    end
  end
end
