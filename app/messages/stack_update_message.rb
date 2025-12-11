require 'messages/metadata_base_message'
require 'models/helpers/stack_states'

module VCAP::CloudController
  class StackUpdateMessage < MetadataBaseMessage
    register_allowed_keys [:state]

    validates_with NoAdditionalKeysValidator
    validates :state, inclusion: { in: StackStates::VALID_STATES, message: "must be one of #{StackStates::VALID_STATES.join(', ')}" }, allow_nil: false, if: :state_requested?

    def state_requested?
      requested?(:state)
    end
  end
end
