require 'cloud_controller/domain_decorator'
require 'models/helpers/label_helpers'

module VCAP::CloudController::Validators
  class LabelValidatorHelper
    MAX_LABEL_SIZE = 63
    MAX_PREFIX_SIZE = 253

    INVALID_CHAR_REGEX = /[^\w\-\.\_]/
    ALPHANUMERIC_START_END_REGEX = /\A(?=[a-zA-Z\d]).*[a-zA-Z\d]\z/

    class << self
      def valid_key?(label_key)
        valid_key_presence?(label_key) &&
          valid_key_format?(label_key) &&
          valid_key_prefix_and_name?(label_key)
      end

      def valid_value?(label_value)
        valid_characters?(label_value) &&
          start_end_alphanumeric?(label_value) &&
          valid_size?(label_value)
      end

      def valid_characters?(label_key_or_value)
        !INVALID_CHAR_REGEX.match?(label_key_or_value)
      end

      def start_end_alphanumeric?(label_key_or_value)
        ALPHANUMERIC_START_END_REGEX.match?(label_key_or_value)
      end

      def valid_size?(label_key_or_value)
        label_key_or_value.size <= LabelValidatorHelper::MAX_LABEL_SIZE
      end

      def valid_key_prefix_and_name?(label_key)
        prefix, name = VCAP::CloudController::LabelHelpers.extract_prefix(label_key)

        valid_prefix_format?(prefix) &&
          valid_prefix_size?(prefix) &&
          valid_key_presence?(name) &&
          valid_characters?(name) &&
          start_end_alphanumeric?(name) &&
          valid_size?(name)
      end

      def valid_prefix_format?(label_key_prefix)
        return true if label_key_prefix.nil?

        CloudController::DomainDecorator::DOMAIN_REGEX.match(label_key_prefix)
      end

      def valid_prefix_size?(label_key_prefix)
        return true if label_key_prefix.nil?

        label_key_prefix.size <= LabelValidatorHelper::MAX_PREFIX_SIZE
      end

      def valid_key_presence?(label_key)
        !label_key.nil? && label_key.size > 0
      end

      def valid_key_format?(label_key)
        label_key.count('/') <= 1
      end
    end
  end
end
