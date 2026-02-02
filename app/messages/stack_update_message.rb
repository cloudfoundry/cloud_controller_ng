require 'messages/metadata_base_message'
require 'models/helpers/stack_states'

module VCAP::CloudController
  class StackUpdateMessage < MetadataBaseMessage
    register_allowed_keys %i[state state_reason]

    validates_with NoAdditionalKeysValidator
    validates :state, inclusion: { in: StackStates::VALID_STATES, message: "must be one of #{StackStates::VALID_STATES.join(', ')}" }, allow_nil: false, if: :state_requested?
    validates :state_reason, length: { maximum: 1000 }, allow_nil: true

    def state_requested?
      requested?(:state)
    end

    def state_reason_requested?
      requested?(:state_reason)
    end
  end
end
