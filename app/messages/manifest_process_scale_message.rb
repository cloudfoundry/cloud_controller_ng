require 'messages/base_message'

module VCAP::CloudController
  class ManifestProcessScaleMessage < BaseMessage
    register_allowed_keys [:instances, :memory, :disk_quota, :type]
    INVALID_MB_VALUE_ERROR = 'must be greater than 0MB'.freeze

    validates_with NoAdditionalKeysValidator

    validates :instances, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
    validates :memory, numericality: { only_integer: true, greater_than: 0, message: INVALID_MB_VALUE_ERROR }, allow_nil: true
    validates :disk_quota, numericality: { only_integer: true, greater_than: 0, message: INVALID_MB_VALUE_ERROR }, allow_nil: true

    def to_process_scale_message
      ProcessScaleMessage.new({
        instances: instances,
        memory_in_mb: memory,
        disk_in_mb: disk_quota,
      }.compact)
    end
  end
end
