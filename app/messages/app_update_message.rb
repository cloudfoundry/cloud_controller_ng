require 'messages/base_message'
require 'messages/buildpack_lifecycle_data_message'

module VCAP::CloudController
  class AppUpdateMessage < BaseMessage
    register_allowed_keys [:name, :lifecycle, :metadata]

    MAX_LABEL_SIZE = 63
    MAX_PREFIX_SIZE = 253

    attr_reader :app

    def self.lifecycle_requested?
      @lifecycle_requested ||= proc { |a| a.requested?(:lifecycle) }
    end

    def self.metadata_requested?
      @metadata_requested ||= proc { |a| a.requested?(:metadata) }
    end

    validates_with NoAdditionalKeysValidator
    validates_with LifecycleValidator, if: lifecycle_requested?
    validates_with MetadataValidator, if: metadata_requested?

    validates :name, string: true, allow_nil: true

    validates :lifecycle_type,
      string: true,
      allow_nil: false,
      if: lifecycle_requested?

    validates :lifecycle_data,
      hash: true,
      allow_nil: false,
      if: lifecycle_requested?

    def labels
      HashUtils.dig(metadata, :labels)
    end

    def lifecycle_data
      HashUtils.dig(lifecycle, :data)
    end

    def lifecycle_type
      HashUtils.dig(lifecycle, :type)
    end

    def buildpack_data
      @buildpack_data ||= BuildpackLifecycleDataMessage.new(lifecycle_data)
    end
  end
end
