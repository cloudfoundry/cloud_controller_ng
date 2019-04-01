require 'messages/base_message'

module VCAP::CloudController
  class SidecarCreateMessage < BaseMessage
    register_allowed_keys [:name, :command, :process_types]

    validates_with NoAdditionalKeysValidator

    validates :name, presence: true, string: true
    validates :command, presence: true, string: true, length: {
      maximum: 4096
    }
    validates :process_types, array: true, length: {
      minimum: 1,
      too_short: 'must have at least %{count} process_type'
    }
  end
end
