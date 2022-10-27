require 'messages/base_message'

module VCAP::CloudController
  class ManifestProcessScaleMessage < BaseMessage
    register_allowed_keys [:instances, :memory, :disk_quota, :log_rate_limit, :type]
    INVALID_MB_VALUE_ERROR = 'must be greater than 0MB'.freeze
    # NOTE: -1 is valid for log_rate_limit representing unlimited
    INVALID_QUOTA_VALUE_ERROR = 'must be an integer greater than or equal to -1'.freeze

    validates_with NoAdditionalKeysValidator

    validates :instances, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 2000000 }, allow_nil: true
    validates :memory, numericality: { only_integer: true, greater_than: 0, message: INVALID_MB_VALUE_ERROR }, allow_nil: true
    validates :disk_quota, numericality: { only_integer: true, greater_than: 0, message: INVALID_MB_VALUE_ERROR }, allow_nil: true
    validates :log_rate_limit,
      numericality: { only_integer: true, greater_than_or_equal_to: -1, less_than_or_equal_to: MAX_DB_BIGINT, message: INVALID_QUOTA_VALUE_ERROR },
      allow_nil: true

    def to_process_scale_message
      ProcessScaleMessage.new({
        instances: instances,
        memory_in_mb: memory,
        disk_in_mb: disk_quota,
        log_rate_limit_in_bytes_per_second: log_rate_limit,
      }.compact)
    end
  end
end
