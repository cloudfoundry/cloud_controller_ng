require 'messages/base_message'

module VCAP::CloudController
  class TaskCreateMessage < BaseMessage
    register_allowed_keys [:name, :command, :disk_in_mb, :memory_in_mb, :droplet_guid]

    validates_with NoAdditionalKeysValidator

    validates :disk_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :memory_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
    validates :droplet_guid, guid: true, allow_nil: true
  end
end
