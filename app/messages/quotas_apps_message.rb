require 'messages/metadata_base_message'
require 'messages/validators'

module VCAP::CloudController
  class QuotasAppsMessage < BaseMessage
    register_allowed_keys [:total_memory_in_mb, :per_process_memory_in_mb, :total_instances, :per_app_tasks, :log_rate_limit_in_bytes_per_second]

    validates_with NoAdditionalKeysValidator

    validates :total_memory_in_mb,
      numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_DB_INT },
      allow_nil: true

    validates :per_process_memory_in_mb,
      numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_DB_INT },
      allow_nil: true

    validates :total_instances,
      numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_DB_INT },
      allow_nil: true

    validates :per_app_tasks,
      numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_DB_INT },
      allow_nil: true

    validates :log_rate_limit_in_bytes_per_second,
      numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_DB_BIGINT },
      allow_nil: true
  end
end
