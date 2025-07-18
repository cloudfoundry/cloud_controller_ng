require 'messages/metadata_base_message'

module VCAP::CloudController
  class TaskCreateMessage < MetadataBaseMessage
    register_allowed_keys %i[name command disk_in_mb memory_in_mb log_rate_limit_in_bytes_per_second droplet_guid template user]

    validates_with NoAdditionalKeysValidator

    def self.validate_template?
      @validate_template ||= proc { |a| a.template_requested? }
    end

    def self.user_requested?
      @user_requested ||= proc { |a| a.requested?(:user) }
    end

    validates :disk_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :memory_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :log_rate_limit_in_bytes_per_second, numericality: { only_integer: true, greater_than: -2, less_than_or_equal_to: MAX_DB_BIGINT }, allow_nil: true
    validates :droplet_guid, guid: true, allow_nil: true
    validates :template_process_guid, guid: true, if: validate_template?
    validate :has_command
    validates :user,
              string: true,
              length: { in: 1..255, message: 'must be between 1 and 255 characters' },
              allow_nil: true,
              if: user_requested?

    def template_process_guid
      return unless template_requested?

      process = HashUtils.dig(template, :process)
      HashUtils.dig(process, :guid)
    end

    def template_requested?
      requested?(:template)
    end

    def has_command
      return unless !command && !template

      errors.add(:command, 'No command or template provided')
    end
  end
end
