require 'messages/metadata_base_message'

module VCAP::CloudController
  class BuildUpdateMessage < MetadataBaseMessage
    register_allowed_keys [:state, :error, :lifecycle]
    def self.state_requested?
      proc { |a| a.requested?(:state) }
    end

    validates_with NoAdditionalKeysValidator

    validate :state_is_in_final_states, if: state_requested?
    validate :staged_includes_lifecycle_data, if: state_requested?
    validate :lifecycle_type_is_supported, if: state_requested?
    validates :error, string: true, allow_nil: true

    def state_is_in_final_states
      unless BuildModel::FINAL_STATES.include?(state)
        errors.add(:state, "'#{state}' is not a valid state")
      end
    end

    def staged_includes_lifecycle_data
      if state == BuildModel::STAGED_STATE && lifecycle.blank?
        errors.add(:lifecycle, "'STAGED' builds require lifecycle data")
      end
    end

    def lifecycle_type_is_supported
      return if state != BuildModel::STAGED_STATE
    end
  end
end
