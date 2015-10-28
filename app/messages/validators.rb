require 'active_model'

module VCAP::CloudController::Validators
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

  class EnvironmentVariablesValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      if !value.is_a?(Hash)
        record.errors.add(attribute, 'must be a hash')
      else
        value.keys.each do |key|
          if key =~ /^CF_/i
            record.errors.add(attribute, 'cannot start with CF_')
          elsif key =~ /^VCAP_/i
            record.errors.add(attribute, 'cannot start with VCAP_')
          elsif key =~ /^PORT$/i
            record.errors.add(attribute, 'cannot set PORT')
          end
        end
      end
    end
  end

  class LifecycleDataValidator < ActiveModel::Validator
    def validate(record)
      config = record.data_validation_config
      return if config.skip_validation

      if config.data.nil? && !config.allow_nil
        record.errors[:lifecycle].concat ['data must be present']
      elsif config.data.is_a?(Hash)
        validate_data_model(config, record)
      end
    end

    def validate_data_model(config, record)
      data_model = "VCAP::CloudController::#{config.data_class}".constantize.new(config.data.symbolize_keys)
      if !data_model.valid?
        record.errors[:lifecycle].concat data_model.errors.full_messages
      end
    end
  end

  class RelationshipValidator < ActiveModel::Validator
    def validate(record)
      return if !record.relationships.is_a?(Hash)

      rel = record.class::Relationships.new(record.relationships.symbolize_keys)

      if !rel.valid?
        record.errors[:relationships].concat rel.errors.full_messages
      end
    end
  end

  class ToOneRelationshipValidator < ActiveModel::EachValidator
    def error_message(attribute)
      "must be structured like this: \"#{attribute}: {\"guid\": \"valid-guid\"}\""
    end

    def validate_each(record, attribute, value)
      if has_correct_structure?(value)
        validate_guid(record, attribute, value)
      else
        record.errors.add(attribute, error_message(attribute))
      end
    end

    def validate_guid(record, attribute, value)
      VCAP::CloudController::BaseMessage::GuidValidator.new({ attributes: 'blah' }).validate_each(record, "#{attribute} Guid", value.values.first)
    end

    def has_correct_structure?(value)
      (value.is_a?(Hash) && (value.keys.map(&:to_sym) == [:guid]))
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
      guids     = value.map(&:values).flatten
      validator = VCAP::CloudController::BaseMessage::GuidValidator.new({ attributes: 'blah' })
      guids.each_with_index do |guid, idx|
        validator.validate_each(record, "#{attribute} Guid #{idx}", guid)
      end
    end

    def has_correct_structure?(value)
      (value.is_a?(Array) && value.all? { |hsh| is_a_guid_hash?(hsh) })
    end

    def is_a_guid_hash?(hsh)
      (hsh.keys.map(&:to_sym) == [:guid])
    end
  end
end
