require 'messages/metadata_base_message'
require 'messages/buildpack_lifecycle_data_message'

module VCAP::CloudController
  class AppUpdateMessage < MetadataBaseMessage
    register_allowed_keys [:name, :lifecycle]

    attr_reader :app

    def self.lifecycle_requested?
      @lifecycle_requested ||= proc { |a| a.requested?(:lifecycle) }
    end

    def self.lifecycle_type_requested?
      @lifecycle_type_requested ||= proc { |a| a.requested?(:lifecycle) && a.lifecycle_type.present? }
    end

    validates_with NoAdditionalKeysValidator
    validates_with LifecycleValidator, if: lifecycle_requested?

    validates :name, string: true, allow_nil: true

    validates :lifecycle_type,
      string: true,
      allow_nil: false,
      if: lifecycle_type_requested?

    validates :lifecycle_data,
      hash: true,
      allow_nil: false,
      if: lifecycle_requested?

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
