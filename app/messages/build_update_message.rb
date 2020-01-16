require 'messages/metadata_base_message'

module VCAP::CloudController
  class BuildUpdateMessage < MetadataBaseMessage
    register_allowed_keys [:state, :error]

    validates_with NoAdditionalKeysValidator

    validate :state_is_in_final_states
    validates :error, string: true, allow_nil: true

    private

    def state_is_in_final_states
      return unless state.present?

      unless BuildModel::FINAL_STATES.include?(state)
        errors.add(:state, "'#{state}' is not a valid state")
      end
    end
  end
end
