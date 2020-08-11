require 'messages/base_message'
require 'messages/validators/metadata_validator'
require 'utils/hash_utils'

module VCAP::CloudController
  class MetadataBaseMessage < BaseMessage
    def self.register_allowed_keys(allowed_keys)
      super(allowed_keys + [:metadata])
    end

    def self.metadata_requested?
      @metadata_requested ||= proc { |a| a.requested?(:metadata) }
    end

    validates_with MetadataValidator, if: metadata_requested?

    def labels
      HashUtils.dig(metadata, :labels)
    end

    def annotations
      HashUtils.dig(metadata, :annotations)
    end
  end
end
