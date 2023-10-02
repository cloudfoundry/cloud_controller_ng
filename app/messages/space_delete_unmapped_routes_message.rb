require 'messages/base_message'

module VCAP::CloudController
  class SpaceDeleteUnmappedRoutesMessage < BaseMessage
    register_allowed_keys [:unmapped]

    validates_with NoAdditionalKeysValidator

    validates :unmapped, presence: true
    validate :unmapped_valid?

    private

    def unmapped_valid?
      errors.add(:base, "Mass delete not supported for routes. Use 'unmapped=true' parameter to delete all unmapped routes.") unless requested?(:unmapped)

      unless %w[true false].include?(unmapped)
        errors.add(:unmapped, 'must be a boolean')
        return
      end

      return unless unmapped == 'false'

      errors.add(:base, "Mass delete not supported for mapped routes. Use 'unmapped=true' parameter to delete all unmapped routes.")
    end
  end
end
