require 'messages/metadata_base_message'
require 'models/helpers/stack_states'

module VCAP::CloudController
  class StackCreateMessage < MetadataBaseMessage
    register_allowed_keys %i[name description state]

    validates :name, presence: true, length: { maximum: 250 }
    validates :description, length: { maximum: 250 }
    validates :state, inclusion: { in: StackStates::VALID_STATES, message: "must be one of #{StackStates::VALID_STATES.join(', ')}" }, allow_nil: true

    def state
      return @state if defined?(@state)

      @state = requested?(:state) ? super : StackStates::DEFAULT_STATE
    end
  end
end
