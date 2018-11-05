require 'cloud_controller/domain_decorator'
require 'models/helpers/label_error'
require 'models/helpers/label_helpers'

module VCAP::CloudController::Validators
  class LabelValidatorHelper
    MAX_LABEL_SIZE = 63
    MAX_PREFIX_SIZE = 253

    INVALID_CHAR_REGEX = /[^\w\-\.]/
    ALPHANUMERIC_START_END_REGEX = /\A(?=[a-zA-Z\d]).*[a-zA-Z\d]\z/

    RESERVED_DOMAIN = 'cloudfoundry.org'.freeze

    LABEL_KEY_EMPTY_ERROR = 'label key cannot be empty string'.freeze

    LABEL_KEY_MULTIPLE_SLASHES = "label key has more than one '/'".freeze

    LabelError = VCAP::CloudController::LabelError

    class << self
      def valid_key?(label_key)
        res = valid_key_presence?(label_key)
        return res unless res.is_valid?
        res = valid_key_format?(label_key)
        return res unless res.is_valid?
        valid_key_prefix_and_name?(label_key)
      end

      def valid_value?(label_value)
        res = valid_characters?(label_value)
        return res unless res.is_valid?
        res = start_end_alphanumeric?(label_value)
        return res unless res.is_valid?
        valid_size?(label_value)
      end

      def valid_characters?(label_key_or_value)
        return LabelError.none unless INVALID_CHAR_REGEX.match?(label_key_or_value)
        LabelError.error("label '#{label_key_or_value}' contains invalid characters")
      end

      def start_end_alphanumeric?(label_key_or_value)
        return LabelError.none if ALPHANUMERIC_START_END_REGEX.match?(label_key_or_value)
        LabelError.error("label '#{label_key_or_value}' starts or ends with invalid characters")
      end

      def valid_size?(label_key_or_value)
        return LabelError.none if label_key_or_value.size <= LabelValidatorHelper::MAX_LABEL_SIZE
        LabelError.error("label '#{label_key_or_value[0...8]}...' is greater than #{LabelValidatorHelper::MAX_LABEL_SIZE} characters")
      end

      def valid_key_prefix_and_name?(label_key)
        prefix, name = VCAP::CloudController::LabelHelpers.extract_prefix(label_key)

        [:valid_prefix_format?, :valid_prefix_size?, :is_not_reserved].each do |method|
          label_result = LabelValidatorHelper.send(method, prefix)
          return label_result unless label_result.is_valid?
        end
        [:valid_key_presence?, :valid_characters?, :start_end_alphanumeric?, :valid_size?].each do |method|
          label_result = LabelValidatorHelper.send(method, name)
          return label_result unless label_result.is_valid?
        end
        LabelError.none
      end

      def valid_prefix_format?(label_key_prefix)
        return LabelError.none if label_key_prefix.nil? ||
                                    CloudController::DomainDecorator::DOMAIN_REGEX.match(label_key_prefix)
        LabelError.error("label prefix '#{label_key_prefix}' must be in valid dns format")
      end

      def is_not_reserved(label_key_prefix)
        return LabelError.none if label_key_prefix.nil? || label_key_prefix.downcase != RESERVED_DOMAIN
        LabelError.error('Cloudfoundry.org is a reserved domain')
      end

      def valid_prefix_size?(label_key_prefix)
        return LabelError.none if label_key_prefix.nil? || label_key_prefix.size <= LabelValidatorHelper::MAX_PREFIX_SIZE
        LabelError.error("label prefix '#{label_key_prefix[0...8]}...' is greater than #{MAX_PREFIX_SIZE} characters")
      end

      def valid_key_presence?(label_key)
        if !label_key.nil? && label_key.size > 0
          return LabelError.none
        end
        LabelError.error(LABEL_KEY_EMPTY_ERROR)
      end

      def valid_key_format?(label_key)
        if label_key.count('/') <= 1
          LabelError.none
        else
          LabelError.error(LABEL_KEY_MULTIPLE_SLASHES)
        end
      end
    end
  end
end
