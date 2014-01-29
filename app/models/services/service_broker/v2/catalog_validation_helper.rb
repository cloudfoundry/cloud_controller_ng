module VCAP::CloudController::ServiceBroker::V2
  module CatalogValidationHelper
    def validate_string!(name, input, opts={})
      if !input.is_a?(String) && !input.nil?
        @errors << "#{human_readable_attr_name(name)} should be a string, but had value #{input.inspect}"
        return
      end

      if opts[:required] && (input.nil? || input.empty? || is_blank_str?(input))
        @errors << "#{human_readable_attr_name(name)} must be non-empty and a string"
      end
    end

    def validate_hash!(name, input)
      @errors << "#{human_readable_attr_name(name)} should be a hash, but had value #{input.inspect}" unless input.is_a? Hash
    end

    def validate_bool!(name, input, opts={})
      if !is_a_bool?(input) && !input.nil?
        @errors << "#{human_readable_attr_name(name)} should be a boolean, but had value #{input.inspect}"
        return
      end

      if opts[:required] && input.nil?
        @errors << "#{human_readable_attr_name(name)} must be present and a boolean"
      end
    end

    def validate_array_of_strings!(name, input)
      unless input.is_a? Array
        @errors << "#{human_readable_attr_name(name)} should be an array of strings, but had value #{input.inspect}"
        return
      end

      input.each do |value|
        @errors << "#{human_readable_attr_name(name)} should be an array of strings, but had value #{input.inspect}" unless value.is_a? String
      end
    end

    def validate_array_of_hashes!(name, input)
      unless input.is_a? Array
        @errors << "#{human_readable_attr_name(name)} should be an array of hashes, but had value #{input.inspect}"
        return
      end

      input.each do |value|
        @errors << "#{human_readable_attr_name(name)} should be an array of hashes, but had value #{input.inspect}" unless value.is_a? Hash
      end
    end

    def is_a_bool?(value)
      [true, false].include?(value)
    end

    def is_blank_str?(value)
      value !~ /[^[:space:]]/
    end
  end
end
