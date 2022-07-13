require 'messages/base_message'

module VCAP::CloudController
  class ProcessScaleMessage < BaseMessage
    register_allowed_keys [:instances, :memory_in_mb, :disk_in_mb, :log_rate_limit_in_bytes_per_second]

    validates_with NoAdditionalKeysValidator

    validates :instances, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_DB_INT }, allow_nil: true
    validates :memory_in_mb, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_DB_INT }, allow_nil: true
    validates :disk_in_mb, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_DB_INT }, allow_nil: true
    validates :log_rate_limit_in_bytes_per_second, numericality: { only_integer: true, greater_than_or_equal_to: -1, less_than_or_equal_to: MAX_DB_BIGINT }, allow_nil: true
  end
end
