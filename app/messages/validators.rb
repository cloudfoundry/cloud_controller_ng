require 'active_model'
require 'utils/uri_utils'
require 'models/helpers/health_check_types'
require 'models/helpers/metadata_error'
require 'models/helpers/metadata_helpers'
require 'models/helpers/label_selector_requirement'
require 'cloud_controller/domain_decorator'
require 'messages/metadata_validator_helper'

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
      record.errors.add attribute, 'must be an object' unless value.is_a?(Hash)
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
        record.errors.add(attribute, 'must be an object')
      else
        value.each_key do |key|
          if ![String, Symbol].include?(key.class)
            record.errors.add(attribute, 'key must be a string')
          elsif key.empty?
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

  class EnvironmentVariablesStringValuesValidator < ActiveModel::EachValidator
    extend StandaloneValidator

    def validate_each(record, attribute, value)
      if !value.is_a?(Hash)
        record.errors.add(attribute, 'must be an object')
      else
        value.each do |key, inner_value|
          if ![String, Symbol].include?(key.class)
            record.errors.add(attribute, 'key must be a string')
          elsif key.empty?
            record.errors.add(attribute, 'key must be a minimum length of 1')
          elsif key.match?(/\AVCAP_/i)
            record.errors.add(attribute, 'cannot start with VCAP_')
          elsif key.match?(/\AVMC/i)
            record.errors.add(attribute, 'cannot start with VMC_')
          elsif key.match?(/\APORT\z/i)
            record.errors.add(attribute, 'cannot set PORT')
          elsif ![String, NilClass].include?(inner_value.class)
            record.errors.add(:base, "Non-string value in environment variable for key '#{key}', value '#{inner_value}'")
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
        VCAP::CloudController::Lifecycles::DOCKER => VCAP::CloudController::EmptyLifecycleDataMessage,
        VCAP::CloudController::Lifecycles::KPACK => VCAP::CloudController::EmptyLifecycleDataMessage,
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

  class RelationshipValidator < ActiveModel::Validator
    def validate(record)
      if !record.relationships.is_a?(Hash)
        record.errors[:relationships].concat ["'relationships' is not an object"]
        return
      end

      if record.relationships.empty?
        record.errors[:relationships].concat ["'relationships' must include one or more valid relationships"]
        return
      end

      rel = record.relationships_message

      if !rel.valid?
        record.errors[:relationships].concat(rel.errors.full_messages)
      end
    end
  end

  class RulesValidator < ActiveModel::EachValidator
    extend StandaloneValidator

    def validate_each(record, attribute, value)
      return unless value.is_a?(Array)

      # value.each_with_index do |rule, index|
      #   protocol = rule['protocol']
      #
      #   validation_errors = case protocol
      #                       when 'tcp', 'udp'
      #                         CloudController::TransportRuleValidator.validate(rule)
      #                       when 'icmp'
      #                         CloudController::ICMPRuleValidator.validate(rule)
      #                       when 'all'
      #                         CloudController::RuleValidator.validate(rule)
      #                       else
      #                         ['contains an unsupported protocol']
      #                       end
      #
      #   validation_errors.each do |error_text|
      #     errors.add(:rules, "rule number #{index + 1} #{error_text}")
      #   end
      #   errors.empty?
      # end
      value.each { |rule|
        unless rule.is_a?(Hash)
          record.errors.add attribute, 'must be an array of hashes'
          return
        end

        record.errors.add :protocol, "must be 'tcp', 'udp', 'icmp', or 'all'" unless valid_protocol(rule[:protocol])

        destination_is_valid(rule[:destination], record.errors)

        if rule[:description]
          record.errors.add :description, "must be a string" unless rule[:description].is_a?(String)
        end

        if rule[:log]
          record.errors.add :log, 'must be a boolean' unless is_boolean(rule[:log])
        end

        case rule[:protocol]
          when 'tcp', 'udp'
            unless rule[:ports]
              record.errors.add :ports, "are required for protocols of type TCP and UDP"
            end

            record.errors.add :ports, 'must be a valid single port, comma separated list of ports, or range or ports, formatted as a string' unless \
          valid_ports(rule[:ports])

          when 'icmp'
            unless rule[:code]
              record.errors.add :code, "is required for protocols of type ICMP"
            end

            unless rule[:type]
              record.errors.add :type, "is required for protocols of type ICMP"
            end

            if rule[:type]
              record.errors.add :type, "must be an integer between -1 and 255 (inclusive)" unless \
            valid_icmp(rule[:type])
            end

            if rule[:code]
              record.errors.add :code, "must be an integer between -1 and 255 (inclusive)" unless \
            valid_icmp(rule[:code])
            end

          when 'all'
            if rule[:protocol] == "all" && rule[:ports]
              record.errors.add :ports, "are not allowed for protocols of type all"
            end
        end
      }
    end

    def is_boolean(value)
      [true, false].include? value
    end

    def valid_protocol(protocol)
      protocol&.is_a?(String) && %w(tcp udp icmp all).include?(protocol)
    end

    def valid_icmp(icmp_type)
      icmp_type.is_a?(Integer) && icmp_type >= -1 && icmp_type <= 255
    end

    def valid_ports(ports)
      return false unless ports&.is_a?(String)
      return false if /[^\d\s\-,]/.match?(ports)

      port_range = /\A\s*(\d+)\s*-\s*(\d+)\s*\z/.match(ports)
      if port_range
        left = port_range.captures[0].to_i
        right = port_range.captures[1].to_i

        return false if left >= right
        return false unless port_in_range(left) && port_in_range(right)

        return true
      end

      port_list = ports.split(',')
      if !port_list.empty?
        return false unless port_list.all? { |p| /\A\s*\d+\s*\z/.match(p) }
        return false unless port_list.all? { |p| port_in_range(p.to_i) }

        return true
      end

      false
    end

    def port_in_range(port)
      port > 0 && port < 65536
    end

    # TODO: rename to match helper function naming convention
    def destination_is_valid(destination, errors)
      #record.errors.add :destination, "must be a valid CIDR, IP address, or IP address range and may not contain whitespace"
      if destination.blank?
        errors.add :destination, 'must be a valid CIDR, IP address, or IP address range'
        return false
      end

      unless destination.is_a?(String)
        errors.add :destination, 'must be a string'
        return false
      end

      if /\s/ =~ destination
        errors.add :destination, 'must not contain whitespace'
        return false
      end


      address_list = destination.split('-')

      if address_list.length > 2
        errors.add :destination, 'must be a valid CIDR, IP address, or IP address range'
        return false
      end

      if address_list.length == 1
        NetAddr::IPv4Net.parse(address_list.first)
        return true
      end

      ipv4s = address_list.map do |address|
        NetAddr::IPv4.parse(address)
      end
      sorted_ipv4s = NetAddr.sort_IPv4(ipv4s)
      return true if ipv4s.first == sorted_ipv4s.first

      errors.add :destination, 'must be a valid CIDR, IP address, or IP address range'
      false
    rescue NetAddr::ValidationError
      errors.add :destination, 'must be a valid CIDR, IP address, or IP address range'
      false
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
      "must be structured like this: \"#{attribute}: {\"data\": [{\"guid\": \"valid-guid\"},{\"guid\": \"valid-guid\"}]}\""
    end

    def validate_each(record, attribute, value)
      if has_correct_structure?(value)
        validate_guids(record, attribute, value[:data])
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

    def properly_formatted_data(data)
      (data.is_a?(Array) && data.all? { |hsh| is_a_guid_hash?(hsh) })
    end

    def has_correct_structure?(value)
      (value.is_a?(Hash) && value.dig(:data) && properly_formatted_data(value[:data]))
    end

    def is_a_guid_hash?(hsh)
      (hsh.keys.map(&:to_s) == ['guid'])
    end
  end
end
