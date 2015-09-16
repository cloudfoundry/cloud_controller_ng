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
end
