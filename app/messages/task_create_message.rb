require 'messages/metadata_base_message'

module VCAP::CloudController
  class TaskCreateMessage < MetadataBaseMessage
    register_allowed_keys [:name, :command, :disk_in_mb, :memory_in_mb, :droplet_guid, :template]

    validates_with NoAdditionalKeysValidator

    def self.template_requested?
      @template_requested ||= proc { |a| a.requested?(:template) }
    end

    validates :disk_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :memory_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :droplet_guid, guid: true, allow_nil: true
    validates :template_process_guid, guid: true, if: template_requested?
    validate :has_command

    def template_process_guid
      process = HashUtils.dig(template, :process)
      HashUtils.dig(process, :guid)
    end

    def has_command
      if !command && !template
        errors.add(:command, 'No command or template provided')
      end
    end
  end
end
