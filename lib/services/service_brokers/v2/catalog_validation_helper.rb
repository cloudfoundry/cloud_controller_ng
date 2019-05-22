require 'vcap/semver_validator'

module VCAP::Services::ServiceBrokers::V2
  module CatalogValidationHelper
    def validate_description!(name, input, opts={})
      validate_string!(name, input, opts)

      if input.respond_to?(:length) && input.length > 10_000
        errors.add("#{human_readable_attr_name(name)} may not have more than 10000 characters")
      end
    end

    def validate_string!(name, input, opts={})
      if !input.is_a?(String) && !input.nil?
        errors.add("#{human_readable_attr_name(name)} must be a string, but has value #{input.inspect}")
        return
      end

      if opts[:required] && (input.nil? || input.empty? || is_blank_str?(input))
        errors.add("#{human_readable_attr_name(name)} is required")
      end
    end

    def validate_hash!(name, input)
      errors.add("#{human_readable_attr_name(name)} must be a hash, but has value #{input.inspect}") unless input.is_a? Hash
    end

    def validate_bool!(name, input, opts={})
      if !is_a_bool?(input) && !input.nil?
        errors.add("#{human_readable_attr_name(name)} must be a boolean, but has value #{input.inspect}")
        return
      end

      if opts[:required] && input.nil?
        errors.add("#{human_readable_attr_name(name)} is required")
      end
    end

    def validate_integer!(name, input, opts={})
      if !input.is_a?(Integer) && !input.nil?
        errors.add("#{human_readable_attr_name(name)} must be an integer, but has value #{input.inspect}")
      end
    end

    def validate_array_of_strings!(name, input)
      unless is_an_array_of(String, input)
        errors.add("#{human_readable_attr_name(name)} must be an array of strings, but has value #{input.inspect}")
      end
    end

    def validate_tags!(name, input)
      if !validate_array_of_strings!(name, input) && !input.empty?
        tags_length = input.join.length
        unless tags_length <= 2048
          errors.add("Tags for the service #{@name} must be 2048 characters or less.")
        end
      end
    end

    def validate_array_of_hashes!(name, input)
      unless is_an_array_of(Hash, input)
        errors.add("#{human_readable_attr_name(name)} must be an array of hashes, but has value #{input.inspect}")
      end
    end

    def validate_dependently_in_order(validations)
      validations.each do |validation|
        errors_count = errors.messages.count
        send(validation)
        break if errors_count != errors.messages.count
      end
    end

    def validate_semver!(name, input, opts={})
      validate_string!(name, input, opts)

      unless VCAP::SemverValidator.valid?(input)
        errors.add("#{human_readable_attr_name(name)} must be a Semantic Version, but has value #{input.inspect}")
      end
    end

    def validate_length_as_json!(name, input, limit)
      length = input.to_json.length
      if length > limit
        errors.add("#{human_readable_attr_name(name)} must serialize to #{limit} characters or fewer in JSON, but serializes to #{length} characters")
      end
    end

    def is_an_array_of(klass, input)
      input.is_a?(Array) && input.all? { |i| i.is_a?(klass) }
    end

    def is_a_bool?(value)
      [true, false].include?(value)
    end

    def is_blank_str?(value)
      value !~ /[^[:space:]]/
    end
  end
end
