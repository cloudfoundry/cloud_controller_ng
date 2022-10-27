require 'messages/metadata_base_message'

module VCAP::CloudController
  class TaskCreateMessage < MetadataBaseMessage
    register_allowed_keys [:name, :command, :disk_in_mb, :memory_in_mb, :log_rate_limit_in_bytes_per_second, :droplet_guid, :template]

    validates_with NoAdditionalKeysValidator

    def self.validate_template?
      @validate_template ||= proc { |a| a.template_requested? }
    end

    validates :disk_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :memory_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :log_rate_limit_in_bytes_per_second, numericality: { only_integer: true, greater_than: -2, less_than_or_equal_to: MAX_DB_BIGINT }, allow_nil: true
    validates :droplet_guid, guid: true, allow_nil: true
    validates :template_process_guid, guid: true, if: validate_template?
    validate :has_command

    def template_process_guid
      return unless template_requested?

      process = HashUtils.dig(template, :process)
      HashUtils.dig(process, :guid)
    end

    def template_requested?
      requested?(:template)
    end

    def has_command
      if !command && !template
        errors.add(:command, 'No command or template provided')
      end
    end
  end
end
