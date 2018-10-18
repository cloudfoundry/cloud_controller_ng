module VCAP::CloudController
  class LabelHelpers
    KEY_SEPARATOR = '/'.freeze

    class << self
      def extract_prefix(full_key)
        return [nil, full_key] unless full_key.include?(KEY_SEPARATOR)

        prefix, key = full_key.split(KEY_SEPARATOR)
        key ||= ''
        [prefix, key]
      end
    end
  end
end
