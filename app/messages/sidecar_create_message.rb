require 'messages/base_message'

module VCAP::CloudController
  class SidecarCreateMessage < BaseMessage
    register_allowed_keys [:name, :command, :process_types, :memory_in_mb]

    validates_with NoAdditionalKeysValidator

    validates :name, presence: true, string: true
    validates :command, presence: true, string: true
    validates :process_types, array: true, length: {
      minimum: 1,
      too_short: 'must have at least %<count>i process_type'
    }
    validates :memory_in_mb, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  end
end
