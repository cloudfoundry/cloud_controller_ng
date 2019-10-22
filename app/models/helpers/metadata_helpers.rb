module VCAP::CloudController
  class MetadataHelpers
    KEY_SEPARATOR = '/'.freeze

    class << self
      def extract_prefix(metadata_key)
        return [nil, metadata_key] unless metadata_key.include?(KEY_SEPARATOR)

        prefix, name = metadata_key.split(KEY_SEPARATOR)
        name ||= ''
        [prefix, name]
      end
    end
  end
end
