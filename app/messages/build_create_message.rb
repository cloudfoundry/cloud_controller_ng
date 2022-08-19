require 'messages/metadata_base_message'
require 'messages/validators'
require 'messages/buildpack_lifecycle_data_message'

module VCAP::CloudController
  class BuildCreateMessage < MetadataBaseMessage
    register_allowed_keys [:staging_memory_in_mb, :staging_disk_in_mb, :staging_log_rate_limit_bytes_per_second, :environment_variables, :lifecycle, :package]

    def self.lifecycle_requested?
      @lifecycle_requested ||= proc { |a| a.requested?(:lifecycle) }
    end

    validates :staging_disk_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :staging_memory_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :staging_log_rate_limit_bytes_per_second, numericality: { only_integer: true, greater_than_or_equal_to: -1, less_than_or_equal_to: MAX_DB_BIGINT }, allow_nil: true

    validates_with NoAdditionalKeysValidator
    validates_with LifecycleValidator, if: lifecycle_requested?

    validates :package_guid,
      presence: true,
      allow_nil: false,
      guid: true

    validates :lifecycle_type,
      string: true,
      allow_nil: false,
      if: lifecycle_requested?

    validates :lifecycle_data,
      hash: true,
      allow_nil: false,
      if: lifecycle_requested?

    def package_guid
      HashUtils.dig(package, :guid)
    end

    def buildpack_data
      @buildpack_data ||= VCAP::CloudController::BuildpackLifecycleDataMessage.new(lifecycle_data)
    end

    def lifecycle_data
      HashUtils.dig(lifecycle, :data)
    end

    def lifecycle_type
      HashUtils.dig(lifecycle, :type)
    end
  end
end
