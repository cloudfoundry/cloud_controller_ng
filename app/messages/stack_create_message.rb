require 'messages/metadata_base_message'
require 'models/helpers/stack_states'

module VCAP::CloudController
  class StackCreateMessage < MetadataBaseMessage
    register_allowed_keys %i[name description state state_reason]

    validates :name, presence: true, length: { maximum: 250 }
    validates :description, length: { maximum: 250 }
    validates :state, inclusion: { in: StackStates::VALID_STATES, message: "must be one of #{StackStates::VALID_STATES.join(', ')}" }, allow_nil: false, if: :state_requested?
    validates :state_reason, length: { maximum: 1000 }, allow_nil: true

    def state_requested?
      requested?(:state)
    end

    def state
      return @state if defined?(@state)

      @state = requested?(:state) ? super : StackStates::DEFAULT_STATE
    end
  end
end
