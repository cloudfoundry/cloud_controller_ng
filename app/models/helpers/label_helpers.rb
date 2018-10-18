module VCAP::CloudController
  class LabelHelpers
    KEY_SEPARATOR = '/'.freeze

    class << self
      def extract_namespace(full_key)
        return [nil, full_key] unless full_key.include?(KEY_SEPARATOR)

        namespace, key = full_key.split(KEY_SEPARATOR)
        key ||= ''
        [namespace, key]
      end
    end
  end
end
