require 'active_model'

module VCAP::CloudController
  class BaseMessage
    include ActiveModel::Model

    class StringValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        record.errors.add attribute, 'must be a string' unless value.is_a?(String)
      end
    end

    class HashValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        record.errors.add attribute, 'must be a hash' unless value.is_a?(Hash)
      end
    end

    class GuidValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        record.errors.add attribute, 'must be a string' unless value.is_a?(String)
        record.errors.add attribute, 'must be between 1 and 200 characters' unless value.is_a?(String) && (1..200).include?(value.size)
      end
    end

    class UriValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        record.errors.add attribute, 'must be a valid URI' unless value =~ /\A#{URI.regexp}\Z/
      end
    end

    class NoAdditionalKeysValidator < ActiveModel::Validator
      def validate(record)
        if record.extra_keys.any?
          record.errors[:base] << "Unknown field(s): '#{record.extra_keys.join("', '")}'"
        end
      end
    end

    class EnvironmentVariablesValidator < ActiveModel::Validator
      def validate(record)
        if record.environment_variables
          if !record.environment_variables.is_a?(Hash)
            record.errors.add(:environment_variables, 'must be a hash')
          else
            record.environment_variables.keys.each do |key|
              if key =~ /^CF_/i
                record.errors.add(:environment_variables, 'cannot start with CF_')
              elsif key =~ /^VCAP_/i
                record.errors.add(:environment_variables, 'cannot start with VCAP_')
              elsif key == 'PORT'
                record.errors.add(:environment_variables, 'cannot set PORT')
              end
            end
          end
        end
      end
    end

    attr_accessor :requested_keys, :extra_keys

    def initialize(params)
      @requested_keys   = params.keys
      disallowed_params = params.slice!(*allowed_keys)
      @extra_keys       = disallowed_params.keys
      super(params)
    end

    def requested?(key)
      requested_keys.include?(key)
    end

    def allowed_keys
    end
  end
end
