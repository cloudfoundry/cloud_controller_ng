require 'messages/base_message'

module VCAP::CloudController
  class SpaceDeleteUnmappedRoutesMessage < BaseMessage
    register_allowed_keys [:unmapped]

    validates_with NoAdditionalKeysValidator

    validates_inclusion_of :unmapped, in: ['true', 'false']
    validates :unmapped, presence: true, string: true
    validate :unmapped_valid?

    private

    def unmapped_valid?
      if self.requested?(:unmapped)
        if self.unmapped == 'false'
          errors.add(:unmapped, "Mass delete not supported for mapped routes. Use 'unmapped=true' parameter to delete all unmapped routes.")
        end
      else
        errors.add(:unmapped, "Mass delete not supported for routes. Use 'unmapped' parameter to delete all unmapped routes.")
      end
    end
  end
end
