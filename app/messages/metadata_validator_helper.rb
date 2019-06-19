require 'cloud_controller/domain_decorator'
require 'models/helpers/metadata_error'
require 'models/helpers/metadata_helpers'

module VCAP::CloudController::Validators
  class MetadataValidatorHelper
    MAX_LABEL_VALUE_SIZE = 63
    MAX_METADATA_KEY_SIZE = 63
    MAX_METADATA_PREFIX_SIZE = 253

    INVALID_CHAR_REGEX = /[^\w\-\.]/.freeze
    ALPHANUMERIC_START_END_REGEX = /\A(?=[a-zA-Z\d]).*[a-zA-Z\d]\z/.freeze

    RESERVED_DOMAIN = 'cloudfoundry.org'.freeze

    MetadataError = VCAP::CloudController::MetadataError

    attr_reader :key, :value, :prefix, :name

    def initialize(key: '', value: '')
      @key   = key.to_s
      @value = value.to_s
      @prefix, @name = VCAP::CloudController::MetadataHelpers.extract_prefix(@key)
    end

    def key_error
      return MetadataError.error('key cannot be empty string') unless valid_key_presence?(key)
      return MetadataError.error("key has more than one '/'") unless valid_key_format?
      return MetadataError.error("prefix '#{prefix}' must be in valid dns format") unless valid_prefix_format?
      return MetadataError.error("prefix '#{prefix[0...8]}...' is greater than #{MAX_METADATA_PREFIX_SIZE} characters") unless valid_prefix_size?
      return MetadataError.error("prefix 'cloudfoundry.org' is reserved") unless is_not_reserved
      return MetadataError.error('key cannot be empty string') unless valid_key_presence?(name)
      return MetadataError.error("'#{name}' contains invalid characters") unless valid_characters?(name)
      return MetadataError.error("'#{name}' starts or ends with invalid characters") unless start_end_alphanumeric?(name)
      return MetadataError.error("'#{name[0...8]}...' is greater than #{MetadataValidatorHelper::MAX_METADATA_KEY_SIZE} characters") unless valid_size?(name)

      MetadataError.none
    end

    def value_error
      return MetadataError.none if value.nil? || value == ''

      return MetadataError.error("'#{value}' contains invalid characters") unless valid_characters?(value)
      return MetadataError.error("'#{value}' starts or ends with invalid characters") unless start_end_alphanumeric?(value)
      return MetadataError.error("'#{value[0...8]}...' is greater than #{MetadataValidatorHelper::MAX_LABEL_VALUE_SIZE} characters") unless valid_size?(value)

      MetadataError.none
    end

    private

    def start_end_alphanumeric?(label_key_or_value)
      ALPHANUMERIC_START_END_REGEX.match?(label_key_or_value)
    end

    def valid_size?(label_key_or_value)
      label_key_or_value.size <= MetadataValidatorHelper::MAX_METADATA_KEY_SIZE
    end

    def valid_characters?(label_key_or_value)
      !INVALID_CHAR_REGEX.match?(label_key_or_value)
    end

    # Key validations

    def valid_prefix_format?
      prefix.nil? || CloudController::DomainDecorator::DOMAIN_REGEX.match(prefix)
    end

    def is_not_reserved
      prefix.nil? || prefix.downcase != RESERVED_DOMAIN
    end

    def valid_prefix_size?
      prefix.nil? || prefix.size <= MetadataValidatorHelper::MAX_METADATA_PREFIX_SIZE
    end

    def valid_key_presence?(key)
      !key.nil? && !key.empty?
    end

    def valid_key_format?
      key.count('/') <= 1
    end
  end
end
